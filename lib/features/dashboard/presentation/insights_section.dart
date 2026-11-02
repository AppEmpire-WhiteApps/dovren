import 'package:flutter/material.dart';

import '../../../core/state/dovren_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../promotions/dovren_promo_card.dart';

class InsightsSection extends StatelessWidget {
  const InsightsSection({required this.state, super.key});

  final DovrenState state;

  @override
  Widget build(BuildContext context) {
    final maximum = state.rules.fold<int>(
      1,
      (largest, rule) =>
          rule.blockedToday > largest ? rule.blockedToday : largest,
    );
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const DovrenPromoCard(margin: EdgeInsets.only(bottom: 20)),
        const Text(
          'INSIGHTS',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'A clear view of what Dovren removed today.',
          style: TextStyle(color: DovrenTheme.muted),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: DovrenTheme.ink,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: DovrenTheme.sage,
                size: 32,
              ),
              const SizedBox(height: 24),
              Text(
                '${state.blockedToday}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'distractions cleared today',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'BY CATEGORY',
          style: TextStyle(
            color: DovrenTheme.muted,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: state.rules.map((rule) {
                final enabled = state.isRuleEnabled(rule);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rule.category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            enabled ? '${rule.blockedToday}' : 'Paused',
                            style: TextStyle(
                              color: enabled
                                  ? DovrenTheme.orange
                                  : DovrenTheme.muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: enabled ? rule.blockedToday / maximum : 0,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(10),
                        backgroundColor: DovrenTheme.cream,
                        color: DovrenTheme.orange,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _PrivacyCard(
          icon: Icons.visibility_off_outlined,
          title: 'Private by design',
          description:
              'Your browsing activity stays on this device. Dovren only reports totals from its local filters.',
        ),
        const SizedBox(height: 10),
        _PrivacyCard(
          icon: Icons.check_circle_outline_rounded,
          title: '${state.allowlisted.length} allowed sites',
          description: state.allowlisted.isEmpty
              ? 'No sites bypass protection.'
              : 'Trusted sites keep their original layout.',
        ),
      ],
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: DovrenTheme.sage,
                foregroundColor: DovrenTheme.ink,
                child: Icon(icon),
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
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: DovrenTheme.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
