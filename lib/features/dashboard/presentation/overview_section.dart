import 'package:flutter/material.dart';

import '../../../core/state/dovren_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../promotions/dovren_promo_card.dart';

class OverviewSection extends StatelessWidget {
  const OverviewSection({
    required this.state,
    required this.onOpenRules,
    required this.onOpenInsights,
    super.key,
  });

  final DovrenState state;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenInsights;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const DovrenPromoCard(margin: EdgeInsets.only(bottom: 20)),
          const Text(
            'AD DOVREN',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'A calmer way\nto read recipes.',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: DovrenTheme.ink,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PROTECTION',
                      style: TextStyle(
                        color: DovrenTheme.sage,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Switch(
                      value: state.protectionEnabled,
                      onChanged: state.setProtection,
                      activeThumbColor: DovrenTheme.sage,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  state.protectionEnabled ? 'ON' : 'PAUSED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  state.protectionEnabled
                      ? '${state.activeRules.length} filters are keeping recipe pages clean.'
                      : 'Turn protection on to hide distractions.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  number: '${state.blockedToday}',
                  label: 'blocked today',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  number: '${state.activeRules.length}/${state.rules.length}',
                  label: 'active filters',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'FOCUS MODE',
            style: TextStyle(
              color: DovrenTheme.muted,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Recipe sites', 'News reading', 'Shopping']
                .map(
                  (mode) => ChoiceChip(
                    label: Text(mode),
                    selected: state.focusMode == mode,
                    onSelected: (_) => state.setFocus(mode),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenRules,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('MANAGE RULES'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenInsights,
                  icon: const Icon(Icons.insights_rounded),
                  label: const Text('VIEW INSIGHTS'),
                ),
              ),
            ],
          ),
        ],
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: DovrenTheme.ink,
                ),
              ),
              Text(label, style: const TextStyle(color: DovrenTheme.muted)),
            ],
          ),
        ),
      );
}
