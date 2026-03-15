/// Chef skill levels with corresponding cook times.
///
/// Ken starts at [trained]. Players can upgrade through
/// [skilled], [expert], and [master] by spending cash.
enum SkillLevel {
  novice(cookTimeSeconds: 60, label: 'Novice', upgradeCost: 0),
  trained(cookTimeSeconds: 45, label: 'Trained', upgradeCost: 100),
  skilled(cookTimeSeconds: 30, label: 'Skilled', upgradeCost: 300),
  expert(cookTimeSeconds: 20, label: 'Expert', upgradeCost: 600),
  master(cookTimeSeconds: 12, label: 'Master', upgradeCost: 0);

  final int cookTimeSeconds;
  final String label;

  /// Cost to upgrade TO this level. 0 means not purchasable.
  final int upgradeCost;

  const SkillLevel({
    required this.cookTimeSeconds,
    required this.label,
    required this.upgradeCost,
  });

  /// The next skill level, or null if already at max.
  SkillLevel? get next {
    final idx = index + 1;
    if (idx >= SkillLevel.values.length) return null;
    return SkillLevel.values[idx];
  }
}
