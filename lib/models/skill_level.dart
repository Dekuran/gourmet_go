/// Chef skill levels with associated cook times.
///
/// See [restaurant_sim_prototype.md §5](../../docs/restaurant_sim_prototype.md)
/// and [flame_implementation.md](../../docs/flame_implementation.md).
enum SkillLevel {
  /// Starting skill. Cook time: 45 seconds.
  trained(cookTimeSeconds: 45, upgradeCost: 0, label: 'Trained'),

  /// First upgrade. Cook time: 30 seconds.
  skilled(cookTimeSeconds: 30, upgradeCost: 500, label: 'Skilled'),

  /// Second upgrade. Cook time: 20 seconds.
  expert(cookTimeSeconds: 20, upgradeCost: 1500, label: 'Expert'),

  /// Final tier. Cook time: 12 seconds.
  master(cookTimeSeconds: 12, upgradeCost: 5000, label: 'Master');

  const SkillLevel({
    required this.cookTimeSeconds,
    required this.upgradeCost,
    required this.label,
  });

  /// How long this chef takes to cook one bowl, in seconds.
  final int cookTimeSeconds;

  /// Cost in yen to upgrade to this level. 0 for the starting level.
  final int upgradeCost;

  /// Human-readable label for UI.
  final String label;

  /// The next skill level, or `null` if already at max.
  SkillLevel? get next {
    final idx = index + 1;
    if (idx >= SkillLevel.values.length) return null;
    return SkillLevel.values[idx];
  }

  /// Whether this is the maximum skill level.
  bool get isMax => next == null;
}
