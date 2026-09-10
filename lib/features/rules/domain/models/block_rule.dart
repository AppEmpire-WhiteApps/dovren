class BlockRule {
  const BlockRule({
    required this.domain,
    required this.category,
    required this.blockedToday,
  });

  final String domain;
  final String category;
  final int blockedToday;
}
