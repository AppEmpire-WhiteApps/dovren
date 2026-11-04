import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'vpn_https_client.dart';

/// Gist controls VPN navigation and the optional configuration shortcut only.
/// Imported profiles never require a subscription or a provisioning backend.
class VpnRemoteConfig extends ChangeNotifier {
  VpnRemoteConfig({
    required Future<String?> Function() read,
    required Future<void> Function(String) write,
    required Future<String> Function() fetch,
    Future<String?> Function()? country,
    DateTime Function()? now,
    this.ioTimeout = const Duration(seconds: 8),
  }) : _read = read,
       _write = write,
       _fetch = fetch,
       _country = country ?? (() async => null),
       _now = now ?? DateTime.now;

  // Dovren — dedicated VPN settings Gist.
  static const _sourceUrlEncrypted =
      'CRBDR0ZeSxpQC0BNF15fFVBBUBNAUkBbXwgRUltBTFAOCRh2QxIFW1IRSlhXV1hOAQILUlBRUwwCV1EF'
      'UVdaBAUHAgdUVlEBVlsLW1tcBAQXRlMRHFNdTkIDCxpDRQwdCxdYWQoSFFtoAVxXX1BRPk4BD1c=';
  static const _sourceCryptoKey = 'ad775dd57b39996a842f37280fe755b3';

  /// URL obfuscation only; the embedded key is not an access secret.
  static String get sourceUrl {
    final data = base64Decode(_sourceUrlEncrypted);
    final key = utf8.encode(_sourceCryptoKey);
    return utf8.decode([
      for (var i = 0; i < data.length; i++) data[i] ^ key[i % key.length],
    ]);
  }

  static const cadence = Duration(hours: 4);
  static const _cacheKey = 'vpn.dovren.gist.settings.v5';
  static const _countryKey = 'vpn.country.v1';
  static const _vault = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static final instance = VpnRemoteConfig(
    read: () => _vault.read(key: _cacheKey),
    write: (value) => _vault.write(key: _cacheKey, value: value),
    fetch: () => const VpnHttpsClient().get(VpnHttpsClient.validate(sourceUrl)),
    country: _resolveCountry,
  );

  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  final Future<String> Function() _fetch;
  final Future<String?> Function() _country;
  final DateTime Function() _now;
  final Duration ioTimeout;
  Map<String, dynamic>? _config;
  DateTime? _attempt;
  Future<void>? _pending;
  String? _countryCode;

  bool get showVpn => _config?['access'] != 'blocked';
  Uri? get portalUrl {
    final value = _config?['address'];
    if (value is! String || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    return uri != null && uri.isScheme('https') && uri.host.isNotEmpty
        ? uri
        : null;
  }

  bool get showGetConfig {
    if (!showVpn || _config?['access'] != 'free' || portalUrl == null) {
      return false;
    }
    if (_config?['russia_only'] == true && _countryCode != 'RU') {
      return false;
    }
    return true;
  }

  Future<void> refresh() =>
      _pending ??= _refresh().whenComplete(() => _pending = null);

  Future<void> _refresh() async {
    final now = _now();
    try {
      final raw = await _read().timeout(ioTimeout);
      if (raw != null) {
        final envelope = jsonDecode(raw) as Map<String, dynamic>;
        final timestamp = envelope['attemptedAt'];
        if (envelope['source'] == sourceUrl && timestamp is int) {
          final attempted = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final value = envelope['config'];
          final cached = value == null ? null : parseConfig(value);
          if (!attempted.isAfter(now) &&
              (_attempt == null || !attempted.isBefore(_attempt!))) {
            _attempt = attempted;
            _config = cached ?? _config;
          }
        }
      }
    } catch (_) {
      // A locked/corrupt Keychain does not erase a valid in-memory snapshot.
    }
    if (_attempt == null || now.difference(_attempt!) >= cadence) {
      _attempt = now;
      try {
        _config = parseConfig(jsonDecode(await _fetch().timeout(ioTimeout)));
      } catch (_) {
        // Offline starts retain the last valid snapshot, or review defaults.
      }
      try {
        await _write(
          jsonEncode({
            'source': sourceUrl,
            'attemptedAt': now.millisecondsSinceEpoch,
            'config': _config,
          }),
        ).timeout(ioTimeout);
      } catch (_) {
        // The in-memory timestamp still enforces the four-hour cadence.
      }
    }
    if (_config?['access'] == 'free') {
      if (_config?['russia_only'] == true) {
        try {
          _countryCode ??= (await _country().timeout(
            ioTimeout,
          ))?.trim().toUpperCase();
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  static Map<String, dynamic> parseConfig(Object? value) {
    const defaults = <String, dynamic>{
      'access': 'review',
      'address': '',
      'russia_only': true,
    };
    if (value is! Map<String, dynamic> ||
        !value.keys.any(defaults.containsKey)) {
      throw const FormatException('Expected VPN settings.');
    }
    final parsed = Map<String, dynamic>.of(defaults);
    for (final entry in defaults.entries) {
      if (!value.containsKey(entry.key)) continue;
      var field = value[entry.key];
      if (entry.value is bool && field is String) {
        field = switch (field.trim().toLowerCase()) {
          'true' => true,
          'false' => false,
          _ => field,
        };
      }
      if ((entry.value is bool && field is! bool) ||
          (entry.value is String && field is! String)) {
        throw const FormatException('Invalid VPN settings.');
      }
      parsed[entry.key] = field is String ? field.trim() : field;
    }
    final state = (parsed['access'] as String).toLowerCase();
    parsed['access'] = ['review', 'free', 'blocked'].contains(state)
        ? state
        : 'review';
    return Map.unmodifiable(parsed);
  }

  static Future<String?> _resolveCountry() async {
    try {
      final cached = await _vault
          .read(key: _countryKey)
          .timeout(const Duration(seconds: 2));
      if (cached != null && RegExp(r'^[A-Z]{2}$').hasMatch(cached)) {
        return cached;
      }
    } catch (_) {}
    try {
      final response = await const VpnHttpsClient().get(
        Uri.https('api.country.is', '/'),
        timeout: const Duration(seconds: 5),
      );
      final data = jsonDecode(response);
      final country = data is Map ? data['country'] : null;
      if (country is! String || !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
        return null;
      }
      try {
        await _vault
            .write(key: _countryKey, value: country)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      return country;
    } catch (_) {
      return null;
    }
  }
}
