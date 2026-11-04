import 'dart:io';

import 'package:flutter_vless/flutter_vless.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum VpnPhase { disconnected, connecting, connected, disconnecting, failed }

abstract class VpnEngine {
  Future<void> initialize(void Function(VpnPhase) onStatus);
  Future<bool> requestPermission();
  Future<void> start({required String label, required String config});
  Future<void> stop();
}

class NativeVpnEngine implements VpnEngine {
  FlutterVless? _engine;

  @override
  Future<void> initialize(void Function(VpnPhase) onStatus) async {
    if (!Platform.isIOS) {
      throw const FormatException('Native VPN is available on iOS only.');
    }
    final info = await PackageInfo.fromPlatform();
    final identifier = info.packageName.trim();
    if (identifier.isEmpty || identifier.endsWith('.XrayTunnel')) {
      throw const FormatException('VPN application identifier is invalid.');
    }
    final engine = FlutterVless(
      onStatusChanged: (status) => onStatus(switch (status.connectionState) {
        VlessConnectionState.connected => VpnPhase.connected,
        VlessConnectionState.connecting => VpnPhase.connecting,
        VlessConnectionState.disconnecting => VpnPhase.disconnecting,
        VlessConnectionState.disconnected ||
        VlessConnectionState.unknown => VpnPhase.disconnected,
      }),
    );
    _engine = engine;
    // The native adapter reads the extension ID from this app's Info.plist.
    // Both processes use the App Group derived from the app's base ID.
    await engine.initializeVless(
      providerBundleIdentifier: identifier,
      groupIdentifier: 'group.$identifier',
      keychainAccessGroup: 'group.$identifier',
    );
  }

  FlutterVless get _ready =>
      _engine ?? (throw const FormatException('VPN is not initialized.'));

  @override
  Future<bool> requestPermission() => _ready.requestPermission();

  @override
  Future<void> start({required String label, required String config}) =>
      _ready.startVless(remark: label, config: config, proxyOnly: false);

  @override
  Future<void> stop() => _ready.stopVless();
}
