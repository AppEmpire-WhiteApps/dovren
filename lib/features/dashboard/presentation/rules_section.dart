import 'package:flutter/material.dart';

import '../../../core/state/dovren_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../promotions/dovren_promo_card.dart';
import '../../rules/domain/models/block_rule.dart';

class RulesSection extends StatelessWidget {
  const RulesSection({required this.state, super.key});

  final DovrenState state;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const DovrenPromoCard(margin: EdgeInsets.only(bottom: 20)),
          const Text(
            'RULES',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${state.activeRules.length} of ${state.rules.length} filters active',
            style: const TextStyle(color: DovrenTheme.muted),
          ),
          const SizedBox(height: 20),
          ...state.rules.map((rule) => _RuleCard(state: state, rule: rule)),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ALLOWLIST',
                      style: TextStyle(
                        color: DovrenTheme.muted,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Sites Dovren should leave untouched',
                      style: TextStyle(color: DovrenTheme.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Add site',
                onPressed: () => _addSite(context),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.allowlisted.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'No allowed sites yet. Add a domain when a trusted page needs its original layout.',
                  style: TextStyle(color: DovrenTheme.muted, height: 1.4),
                ),
              ),
            )
          else
            Material(
              color: Colors.transparent,
              child: Column(
                children: state.allowlisted
                    .map(
                      (domain) => ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: DovrenTheme.sage,
                          child: Icon(Icons.language, color: DovrenTheme.ink),
                        ),
                        title: Text(domain),
                        subtitle: const Text('Protection bypassed'),
                        trailing: IconButton(
                          tooltip: 'Remove',
                          onPressed: () => state.removeAllowlistedSite(domain),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      );

  Future<void> _addSite(BuildContext context) async {
    final controller = TextEditingController();
    final domain = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow a site'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'example.com',
            helperText: 'Enter a domain without https://',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('ALLOW'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (domain != null) await state.addAllowlistedSite(domain);
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.state, required this.rule});

  final DovrenState state;
  final BlockRule rule;

  IconData get icon => switch (rule.category) {
        'Display ads' => Icons.view_carousel_outlined,
        'Tracking pixels' => Icons.visibility_off_outlined,
        'Autoplay video' => Icons.smart_display_outlined,
        _ => Icons.open_in_new_off_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final enabled = state.isRuleEnabled(rule);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: SwitchListTile(
        value: enabled,
        onChanged: (value) => state.setRuleEnabled(rule, value),
        secondary: Icon(icon, color: enabled ? DovrenTheme.orange : null),
        title: Text(
          rule.category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          enabled
              ? '${rule.blockedToday} blocked today · ${rule.domain}'
              : 'Paused · ${rule.domain}',
        ),
      ),
    );
  }
}
