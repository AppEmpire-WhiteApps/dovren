import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_theme.dart';
import '../promotions/dovren_promo_card.dart';
import 'vpn_configurations_screen.dart';
import 'vpn_controller.dart';
import 'vpn_import_sheet.dart';
import 'vpn_portal_banner.dart';
import 'vpn_portal_glow.dart';
import 'vpn_profile_card.dart';
import 'vpn_remote_config.dart';
import 'vpn_ui_message.dart';
import 'vpn_widgets.dart';

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> {
  final _vpn = VpnController.instance;
  final _remote = VpnRemoteConfig.instance;
  final _profilesScroll = ScrollController(keepScrollOffset: false);
  late final _changes = Listenable.merge([_vpn, _remote]);
  bool _loading = true;
  bool _initializationFailed = false;
  bool _starting = false;
  bool _stopping = false;
  bool _editing = false;
  bool _confirmingRemoval = false;
  bool _openingPortal = false;

  bool get _canEdit =>
      !_loading &&
      !_initializationFailed &&
      !_starting &&
      !_stopping &&
      !_editing &&
      !_confirmingRemoval &&
      !_vpn.isBusy &&
      _vpn.canEditProfiles &&
      _remote.showVpn;

  bool get _needsStop => vpnNeedsStop(_vpn);

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _profilesScroll.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _initializationFailed = false;
    });
    try {
      await _vpn.initialize();
    } catch (_) {
      if (mounted) setState(() => _initializationFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _connect() async {
    if (!_canEdit || _vpn.selectedProfile == null) return;
    setState(() => _starting = true);
    try {
      await _vpn.connect();
    } catch (_) {
      _notice(vpnUiMessage(_vpn.error, 'Could not start the VPN.'));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _disconnect() async {
    if (_stopping || _vpn.phase == VpnPhase.disconnecting) return;
    setState(() => _stopping = true);
    try {
      await _vpn.disconnect();
    } catch (_) {
      _notice(vpnUiMessage(_vpn.error, 'Could not disconnect the VPN.'));
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  Future<void> _openImport() async {
    if (!_canEdit) return;
    await showVpnImportSheet(context);
  }

  Future<void> _changeProfile(Future<void> Function() action) async {
    if (!_canEdit) return;
    setState(() => _editing = true);
    try {
      await action();
    } catch (_) {
      _notice(vpnUiMessage(_vpn.error, 'Could not update the saved profiles.'));
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  Future<void> _removeProfile(VpnProfile profile) async {
    if (!_canEdit) return;
    setState(() => _confirmingRemoval = true);
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Remove configuration?'),
          content: Text(profile.label),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _confirmingRemoval = false);
    }
    if (!mounted || confirmed != true || !_canEdit) return;
    await _changeProfile(() => _vpn.removeProfile(profile.id));
  }

  void _openConfigurations() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const VpnConfigurationsScreen()),
    );
  }

  Uri? get _portal {
    final uri = _remote.portalUrl;
    if (!_remote.showVpn || !_remote.showGetConfig || uri == null) return null;
    if (!uri.isScheme('https') || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  Future<void> _openPortal() async {
    final uri = _portal;
    if (uri == null || _openingPortal) return;
    setState(() => _openingPortal = true);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _notice('Could not open config.');
    } catch (_) {
      _notice('Could not open config.');
    } finally {
      if (mounted) setState(() => _openingPortal = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) {
      final phase = _vpn.phase;
      final connected = phase == VpnPhase.connected;
      final shifting =
          phase == VpnPhase.connecting || phase == VpnPhase.disconnecting;
      final status = switch (phase) {
        VpnPhase.disconnected => 'Not connected',
        VpnPhase.connecting => 'Connecting…',
        VpnPhase.connected => 'Connected',
        VpnPhase.disconnecting => 'Disconnecting…',
        VpnPhase.failed => 'Failed',
      };
      final canStop =
          _needsStop && !_stopping && phase != VpnPhase.disconnecting;
      final error = _vpn.error;
      final hasPortal = _portal != null;
      final selectedId = _vpn.selectedProfile?.id;
      final profiles = [
        for (final profile in _vpn.profiles)
          if (profile.id == selectedId) profile,
        for (final profile in _vpn.profiles)
          if (profile.id != selectedId) profile,
      ];
      final buttonLabel = _stopping || phase == VpnPhase.disconnecting
          ? 'Disconnecting…'
          : phase == VpnPhase.connecting
          ? 'Stop'
          : _needsStop
          ? 'Disconnect'
          : _starting
          ? 'Starting…'
          : 'Connect';
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            VpnShieldEmblem(connected: connected),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'VPN',
                                    style: TextStyle(
                                      color: DovrenTheme.ink,
                                      fontSize: 18,
                                      height: 1.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: phase == VpnPhase.failed
                                            ? vpnFault
                                            : DovrenTheme.muted,
                                        fontSize: 13,
                                        height: 1.25,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _needsStop
                              ? (canStop ? _disconnect : null)
                              : (_canEdit && _vpn.selectedProfile != null
                                    ? _connect
                                    : null),
                          style: FilledButton.styleFrom(
                            backgroundColor: DovrenTheme.ink,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          icon: Icon(
                            _needsStop
                                ? Icons.stop_rounded
                                : Icons.power_settings_new_rounded,
                          ),
                          label: Text(buttonLabel),
                        ),
                        const SizedBox(height: 6),
                        if (hasPortal) ...[
                          VpnPortalGlow(
                            enabled: !_openingPortal,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(24),
                            ),
                            child: FilledButton.icon(
                              onPressed: _openingPortal ? null : _openPortal,
                              style: FilledButton.styleFrom(
                                backgroundColor: DovrenTheme.sage,
                                foregroundColor: DovrenTheme.ink,
                                minimumSize: const Size.fromHeight(48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 18,
                              ),
                              label: const Text('Get Configuration'),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        OutlinedButton.icon(
                          onPressed: _canEdit ? _openImport : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: DovrenTheme.ink,
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('Add Configuration'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Configurations (${profiles.length})',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: DovrenTheme.ink,
                                  fontSize: 14,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _openConfigurations,
                              style: TextButton.styleFrom(
                                foregroundColor: DovrenTheme.ink,
                                shape: const StadiumBorder(),
                              ),
                              child: const Text('Manage'),
                            ),
                          ],
                        ),
                        if (profiles.isEmpty)
                          const VpnPanel(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No saved configurations yet.',
                              style: TextStyle(color: DovrenTheme.muted),
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 128),
                            child: Scrollbar(
                              controller: _profilesScroll,
                              thumbVisibility: true,
                              child: ListView.separated(
                                key: ValueKey(selectedId),
                                controller: _profilesScroll,
                                primary: false,
                                shrinkWrap: true,
                                padding: const EdgeInsets.only(right: 6),
                                itemCount: profiles.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final profile = profiles[index];
                                  return VpnProfileCard(
                                    key: ValueKey(profile.id),
                                    label: profile.label,
                                    flag: profile.flag,
                                    countryName: profile.countryName,
                                    selected: profile.id == selectedId,
                                    onSelect: _canEdit
                                        ? () => _changeProfile(
                                            () =>
                                                _vpn.selectProfile(profile.id),
                                          )
                                        : null,
                                    onRemove: _canEdit
                                        ? () => _removeProfile(profile)
                                        : null,
                                  );
                                },
                              ),
                            ),
                          ),
                        if (_needsStop && profiles.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const VpnMessage(
                            'Disconnect to change configurations.',
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasPortal)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                      child: VpnPortalBanner(
                        onTap: _openingPortal ? null : _openPortal,
                      ),
                    )
                  else
                    const DovrenPromoCard(
                      margin: EdgeInsets.fromLTRB(6, 8, 6, 0),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (shifting) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(
                            color: DovrenTheme.muted,
                            backgroundColor: vpnSageWash,
                            minHeight: 2,
                          ),
                        ],
                        if (_loading) ...[
                          const SizedBox(height: 16),
                          const LinearProgressIndicator(),
                        ],
                        if (_initializationFailed || error != null) ...[
                          const SizedBox(height: 16),
                          VpnMessage(
                            vpnUiMessage(
                              error,
                              'Could not initialize the VPN. Try again.',
                            ),
                            isError: true,
                          ),
                          if (_initializationFailed)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _loading ? null : _initialize,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ),
                        ],
                        if (!_remote.showVpn) ...[
                          const SizedBox(height: 16),
                          const VpnMessage(
                            'VPN unavailable. You can still disconnect.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
