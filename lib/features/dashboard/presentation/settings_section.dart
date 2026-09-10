import 'package:flutter/material.dart';

import '../../../core/settings/quiet_rules_info_panel.dart';
import '../../../core/state/dovren_state.dart';
import '../../../core/theme/app_theme.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({required this.state, super.key});

  final DovrenState state;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text(
            'SETTINGS',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 22),
          const _SectionLabel('PROTECTION'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: state.protectionEnabled,
                  onChanged: state.setProtection,
                  secondary: const Icon(Icons.shield_outlined),
                  title: const Text('Safari protection'),
                  subtitle: const Text('Block distractions while browsing'),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  value: state.strictMode,
                  onChanged: state.setStrictMode,
                  secondary: const Icon(Icons.security_rounded),
                  title: const Text('Strict protection'),
                  subtitle: const Text('Keep every available filter enabled'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionLabel('SAFARI EXTENSION'),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              onTap: () => _showSafariGuide(context),
              leading: const Icon(Icons.extension_outlined),
              title: const Text('Set up in Safari'),
              subtitle: const Text('Follow the activation checklist'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 22),
          const _SectionLabel('DOVREN'),
          const SizedBox(height: 10),
          const Card(
            child: QuietRulesInfoPanel(
              appName: 'Dovren',
              accent: DovrenTheme.orange,
              textColor: DovrenTheme.muted,
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Calmer pages. Fewer distractions.',
              style: TextStyle(color: DovrenTheme.muted, fontSize: 12),
            ),
          ),
        ],
      );

  void _showSafariGuide(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enable Dovren in Safari',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 20),
                const _SetupStep(
                  number: '1',
                  title: 'Open Settings',
                  description: 'Go to Apps → Safari → Extensions.',
                ),
                const _SetupStep(
                  number: '2',
                  title: 'Choose Dovren',
                  description: 'Turn on the Dovren content blocker.',
                ),
                const _SetupStep(
                  number: '3',
                  title: 'Allow on websites',
                  description: 'Give Dovren permission for recipe sites.',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('GOT IT'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: DovrenTheme.muted,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      );
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: DovrenTheme.sage,
              foregroundColor: DovrenTheme.ink,
              child: Text(
                number,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(color: DovrenTheme.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
