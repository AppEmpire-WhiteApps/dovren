import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'vpn_remote_config.dart';
import 'vpn_screen.dart';

class VpnEntry extends StatefulWidget {
  const VpnEntry({super.key});

  @override
  State<VpnEntry> createState() => _VpnEntryState();
}

class _VpnEntryState extends State<VpnEntry> with WidgetsBindingObserver {
  final _remote = VpnRemoteConfig.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      await _remote.refresh();
    } catch (_) {
      // Remote config keeps the offline/review defaults; launch never waits.
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _remote,
    builder: (context, _) {
      if (!_remote.showVpn) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 12,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: DovrenTheme.sage,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.vpn_key_outlined, color: DovrenTheme.ink),
            ),
            title: const Text(
              'Your VPN connection',
              style: TextStyle(
                color: DovrenTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Import your own configuration. Separate from Safari filters.',
              style: TextStyle(color: DovrenTheme.muted),
            ),
            trailing: const Icon(Icons.arrow_forward, color: DovrenTheme.ink),
            onTap: () {
              if (!_remote.showVpn) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const VpnScreen()),
              );
            },
          ),
        ),
      );
    },
  );
}
