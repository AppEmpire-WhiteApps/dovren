import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_theme.dart';
import 'vpn_controller.dart';
import 'vpn_import_sheet.dart';
import 'vpn_portal_glow.dart';
import 'vpn_profile_card.dart';
import 'vpn_remote_config.dart';
import 'vpn_ui_message.dart';
import 'vpn_widgets.dart';

class VpnConfigurationsScreen extends StatefulWidget {
  const VpnConfigurationsScreen({super.key});

  @override
  State<VpnConfigurationsScreen> createState() =>
      _VpnConfigurationsScreenState();
}

class _VpnConfigurationsScreenState extends State<VpnConfigurationsScreen> {
  final _vpn = VpnController.instance;
  final _remote = VpnRemoteConfig.instance;
  late final _changes = Listenable.merge([_vpn, _remote]);
  bool _loading = true;
  bool _initializationFailed = false;
  bool _editing = false;
  bool _confirmingRemoval = false;
  bool _openingPortal = false;

  bool get _canEdit =>
      !_loading &&
      !_initializationFailed &&
      !_editing &&
      !_confirmingRemoval &&
      !_vpn.isBusy &&
      _vpn.canEditProfiles &&
      _remote.showVpn;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
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

  Future<void> _openImport() async {
    if (!_canEdit) return;
    await showVpnImportSheet(context);
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
      if (!opened) _notice('Could not open the configuration website.');
    } catch (_) {
      _notice('Could not open the configuration website.');
    } finally {
      if (mounted) setState(() => _openingPortal = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Configurations')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (_loading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 14),
                ],
                if (_initializationFailed || _vpn.error != null) ...[
                  VpnMessage(
                    vpnUiMessage(
                      _vpn.error,
                      'Could not initialize the VPN. Try again.',
                    ),
                    isError: true,
                  ),
                  if (_initializationFailed)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _loading ? null : _initialize,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ),
                  const SizedBox(height: 14),
                ],
                for (final profile in _vpn.profiles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: VpnProfileCard(
                      key: ValueKey(profile.id),
                      label: profile.label,
                      flag: profile.flag,
                      countryName: profile.countryName,
                      selected: profile.id == _vpn.selectedProfile?.id,
                      onSelect: _canEdit
                          ? () => _changeProfile(
                              () => _vpn.selectProfile(profile.id),
                            )
                          : null,
                      onRemove: _canEdit ? () => _removeProfile(profile) : null,
                    ),
                  ),
                const SizedBox(height: 8),
                if (_portal != null) ...[
                  VpnPortalGlow(
                    enabled: !_openingPortal,
                    borderRadius: const BorderRadius.all(Radius.circular(24)),
                    child: FilledButton.icon(
                      onPressed: _openingPortal ? null : _openPortal,
                      style: FilledButton.styleFrom(
                        backgroundColor: DovrenTheme.sage,
                        foregroundColor: DovrenTheme.ink,
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Get Configuration'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  onPressed: _canEdit ? _openImport : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: DovrenTheme.sage,
                    foregroundColor: DovrenTheme.ink,
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Configuration'),
                ),
                if (!_remote.showVpn || _vpn.needsStop) ...[
                  const SizedBox(height: 12),
                  VpnMessage(
                    !_remote.showVpn
                        ? 'Configurations unavailable.'
                        : 'Disconnect first.',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
