import '../domain/models/block_rule.dart';

abstract interface class RuleRepository {
  List<BlockRule> rules();
}

/// The protection families surfaced in Dovren's recipe-reading controls.
class RecipeRuleRepository implements RuleRepository {
  const RecipeRuleRepository();

  @override
  List<BlockRule> rules() => const [
        BlockRule(
          domain: 'doubleclick.net',
          category: 'Display ads',
          blockedToday: 84,
        ),
        BlockRule(
          domain: 'google-analytics.com',
          category: 'Tracking pixels',
          blockedToday: 31,
        ),
        BlockRule(
          domain: 'taboola.com',
          category: 'Sponsored widgets',
          blockedToday: 12,
        ),
        BlockRule(
          domain: 'outbrain.com',
          category: 'Reading interruptions',
          blockedToday: 9,
        ),
      ];
}
