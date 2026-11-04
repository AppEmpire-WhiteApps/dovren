import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import 'vpn_controller.dart';
import 'vpn_remote_config.dart';
import 'vpn_ui_message.dart';
import 'vpn_widgets.dart';

Future<void> showVpnImportSheet(BuildContext context) async {
  final vpn = VpnController.instance;
  if (!VpnRemoteConfig.instance.showVpn || vpn.isBusy || !vpn.canEditProfiles) {
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: DovrenTheme.cream,
    constraints: const BoxConstraints(maxWidth: 640),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => const VpnImportSheet(),
  );
}

class VpnImportSheet extends StatefulWidget {
  const VpnImportSheet({super.key});

  @override
  State<VpnImportSheet> createState() => _VpnImportSheetState();
}

class _VpnImportSheetState extends State<VpnImportSheet> {
  final _input = TextEditingController();
  final _vpn = VpnController.instance;
  final _remote = VpnRemoteConfig.instance;
  late final _changes = Listenable.merge([_vpn, _remote]);
  bool _saving = false;
  bool _pasting = false;
  String? _error;

  bool get _canEdit =>
      !_saving &&
      !_pasting &&
      !_vpn.isBusy &&
      _vpn.canEditProfiles &&
      _remote.showVpn;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    if (!_canEdit) return;
    setState(() => _pasting = true);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted ||
          !_remote.showVpn ||
          _vpn.isBusy ||
          !_vpn.canEditProfiles) {
        return;
      }
      final text = data?.text ?? '';
      setState(() {
        if (text.trim().isEmpty) {
          _error = 'The clipboard is empty.';
        } else {
          _input.text = text;
          _error = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not read the clipboard.');
    } finally {
      if (mounted) setState(() => _pasting = false);
    }
  }

  Future<void> _save() async {
    if (!_canEdit) return;
    if (_input.text.trim().isEmpty) {
      setState(() => _error = 'Enter a configuration link.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    var imported = false;
    try {
      await _vpn.addProfile(_input.text);
      imported = true;
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = vpnUiMessage(_vpn.error, 'Could not add configuration.'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (imported && mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) => PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          22,
          22,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add configuration',
                      style: TextStyle(
                        color: DovrenTheme.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _input,
                enabled: _canEdit,
                maxLines: 1,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                style: const TextStyle(fontSize: 14, height: 1.4),
                decoration: InputDecoration(
                  labelText: 'Configuration link',
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (!_remote.showVpn || _vpn.needsStop) ...[
                const SizedBox(height: 12),
                VpnMessage(
                  !_remote.showVpn
                      ? 'Import unavailable.'
                      : 'Disconnect first.',
                  isError: true,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                VpnMessage(_error!, isError: true),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _canEdit ? _paste : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DovrenTheme.ink,
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                      label: Text(_pasting ? 'Pasting…' : 'Paste'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _canEdit ? _save : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: DovrenTheme.ink,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(_saving ? 'Adding…' : 'Add'),
                    ),
                  ),
                ],
              ),
              if (_saving) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(
                  color: DovrenTheme.ink,
                  backgroundColor: DovrenTheme.sage,
                  minHeight: 2,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
