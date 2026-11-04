import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'vpn_engine.dart';
import 'vpn_profile.dart';
import 'vpn_profile_codec.dart';
import 'vpn_profile_importer.dart';

export 'vpn_engine.dart' show VpnPhase;
export 'vpn_profile.dart';

class VpnController extends ChangeNotifier {
  VpnController({
    required VpnEngine engine,
    required Future<String?> Function() read,
    required Future<void> Function(String) write,
    VpnProfileImporter? importer,
    this.startupTimeout = const Duration(seconds: 45),
  }) : _engine = engine,
       _read = read,
       _write = write,
       _importer = importer ?? VpnProfileImporter();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _storageKey = 'vpn.imported.profiles.v1';
  static final instance = VpnController(
    engine: NativeVpnEngine(),
    read: () => _storage.read(key: _storageKey),
    write: (value) => _storage.write(key: _storageKey, value: value),
  );

  final VpnEngine _engine;
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  final VpnProfileImporter _importer;
  final Duration startupTimeout;
  Future<void>? _initializing;
  Future<void>? _starting;
  Timer? _readiness;
  List<VpnProfile> _profiles = [];
  String? _selected;
  VpnPhase _phase = VpnPhase.disconnected;
  String? _error;
  bool _engineReady = false;
  bool _editing = false;
  bool _mayBeRunning = false;
  bool _stopping = false;
  bool _disposed = false;
  int _generation = 0;
  int _nextId = 0;

  List<VpnProfile> get profiles => List.unmodifiable(_profiles);
  VpnProfile? get selectedProfile =>
      _profiles.where((profile) => profile.id == _selected).firstOrNull;
  VpnPhase get phase => _phase;
  String? get error => _error;
  // Profile saves lock editing too; only tunnel state determines Stop access.
  bool get needsStop => !_idle;
  bool get canEditProfiles => !_editing && _idle;
  bool get isBusy =>
      _editing ||
      _phase == VpnPhase.connecting ||
      _phase == VpnPhase.disconnecting;
  bool get _idle =>
      !_mayBeRunning &&
      !_stopping &&
      (_phase == VpnPhase.disconnected || _phase == VpnPhase.failed);

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      final stored = await _read().timeout(const Duration(seconds: 10));
      if (stored != null) {
        final data = jsonDecode(stored) as Map<String, dynamic>;
        final entries = data['profiles'] as List;
        if (entries.length > 30) {
          throw const FormatException('Too many saved VPN profiles.');
        }
        final restored = entries.map((entry) {
          final profile = VpnProfile.fromJson(
            Map<String, dynamic>.from(entry as Map),
          );
          const VpnProfileCodec().normalize(profile.config);
          return profile;
        }).toList();
        final selected = data['selected'] as String?;
        final selection = restored.any((profile) => profile.id == selected)
            ? selected
            : restored.firstOrNull?.id;
        _profiles = restored;
        _selected = selection;
      }
      await _engine.initialize(_onStatus).timeout(const Duration(seconds: 20));
      _engineReady = true;
      _error = null;
      _notify();
    } catch (error) {
      _initializing = null;
      _error = 'VPN initialization failed. Try again.';
      _notify();
      rethrow;
    }
  }

  Future<void> addProfile(String input) => _edit(() async {
    if (_profiles.length >= 30) {
      throw const FormatException('You can save up to 30 VPN profiles.');
    }
    final imported = await _importer.import(input);
    final existing = _profiles
        .where((p) => p.config == imported.config)
        .firstOrNull;
    if (existing != null) {
      if (imported.countryCode.isEmpty ||
          imported.countryCode == existing.countryCode) {
        return (_profiles, existing.id);
      }
      final updated = VpnProfile(
        id: existing.id,
        label: existing.label,
        source: existing.source,
        config: existing.config,
        countryCode: imported.countryCode,
      );
      return (
        [
          for (final profile in _profiles)
            if (profile.id == existing.id) updated else profile,
        ],
        existing.id,
      );
    }
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
    final profile = VpnProfile(
      id: id,
      label: imported.label,
      source: imported.source,
      config: imported.config,
      countryCode: imported.countryCode,
    );
    return ([..._profiles, profile], id);
  });

  Future<void> selectProfile(String id) => _edit(() async {
    if (!_profiles.any((profile) => profile.id == id)) {
      throw const FormatException('Select a saved VPN profile.');
    }
    return (_profiles, id);
  });

  Future<void> removeProfile(String id) => _edit(() async {
    final remaining = _profiles.where((profile) => profile.id != id).toList();
    return (remaining, _selected == id ? remaining.firstOrNull?.id : _selected);
  });

  Future<void> _edit(
    Future<(List<VpnProfile>, String?)> Function() change,
  ) async {
    if (!canEditProfiles) {
      throw const FormatException(
        'Disconnect the VPN before changing profiles.',
      );
    }
    _editing = true;
    _notify();
    try {
      await initialize();
      if (!_idle) {
        throw const FormatException(
          'Disconnect the VPN before changing profiles.',
        );
      }
      final (next, selected) = await change();
      if (!_idle) {
        throw const FormatException(
          'Disconnect the VPN before changing profiles.',
        );
      }
      await _write(
        jsonEncode({
          'profiles': next.map((profile) => profile.toJson()).toList(),
          'selected': selected,
        }),
      ).timeout(const Duration(seconds: 10));
      _profiles = next;
      _selected = selected;
      _error = null;
    } catch (error) {
      _error = _safeError(error, 'Could not save this VPN configuration.');
      rethrow;
    } finally {
      _editing = false;
      _notify();
    }
  }

  Future<void> connect() {
    if (_starting != null) return _starting!;
    if (_phase == VpnPhase.connected) return Future.value();
    if (!canEditProfiles) {
      _error = 'Disconnect the VPN before starting another connection.';
      _notify();
      return Future.error(const FormatException('VPN is busy.'));
    }
    return _starting = _connect().whenComplete(() => _starting = null);
  }

  Future<void> _connect() async {
    final generation = ++_generation;
    _phase = VpnPhase.connecting;
    _error = null;
    _notify();
    try {
      await initialize();
      if (generation != _generation) return;
      final profile = selectedProfile;
      if (profile == null) {
        throw const FormatException(
          'Add and select a VPN configuration first.',
        );
      }
      final config = const VpnProfileCodec().normalize(profile.config);
      final allowed = await _engine.requestPermission().timeout(
        const Duration(seconds: 60),
      );
      if (generation != _generation) return;
      if (!allowed) throw const FormatException('VPN permission was denied.');
      _mayBeRunning = true;
      _armReadiness();
      await _engine
          .start(label: profile.label, config: config)
          .timeout(const Duration(seconds: 30));
      // Only a native status event can move Connecting to Connected.
    } catch (error) {
      if (generation == _generation) {
        _readiness?.cancel();
        _phase = VpnPhase.failed;
        _error = _safeError(
          error,
          'VPN could not start. Disconnect and try again.',
        );
        _notify();
        rethrow;
      }
    }
  }

  Future<void> disconnect() async {
    if (_stopping) return;
    ++_generation;
    _stopping = true;
    _readiness?.cancel();
    _phase = VpnPhase.disconnecting;
    _notify();
    try {
      final initializing = _initializing;
      if (!_engineReady && initializing != null) {
        await initializing;
      }
      if (_engineReady) {
        await _engine.stop().timeout(const Duration(seconds: 10));
      }
      _mayBeRunning = false;
      _phase = VpnPhase.disconnected;
      _error = null;
    } catch (_) {
      _mayBeRunning = true;
      _phase = VpnPhase.failed;
      _error = 'VPN could not stop. Tap Disconnect again.';
      rethrow;
    } finally {
      _stopping = false;
      _notify();
    }
  }

  void _onStatus(VpnPhase status) {
    if (_stopping || _disposed) return;
    if (status == VpnPhase.connected) {
      _mayBeRunning = true;
      _phase = VpnPhase.connected;
      _error = null;
      _readiness?.cancel();
    } else if (_mayBeRunning) {
      _phase = VpnPhase.connecting;
      _armReadiness();
    } else if (_phase != VpnPhase.connecting) {
      _phase = status;
    }
    _notify();
  }

  void _armReadiness() {
    if (_readiness?.isActive == true) return;
    _readiness = Timer(startupTimeout, () {
      _phase = VpnPhase.failed;
      _error = 'VPN is not ready. Disconnect and check your configuration.';
      _notify();
    });
  }

  static String _safeError(Object error, String fallback) {
    if (error is FormatException) return error.message;
    if (error is TimeoutException) {
      return 'Operation timed out. Disconnect and try again.';
    }
    return fallback;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _readiness?.cancel();
    super.dispose();
  }
}
