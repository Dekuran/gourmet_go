import 'skill_level.dart';

/// A chef in the player's restaurant.
///
/// For the prototype, there is a single chef (Ken) who starts
/// at [SkillLevel.trained] and can be upgraded to [SkillLevel.master].
///
/// See [flame_implementation.md §Data Models](../../docs/flame_implementation.md).
class ChefProfile {
  ChefProfile({
    required this.name,
    this.skill = SkillLevel.trained,
  });

  /// Chef display name.
  final String name;

  /// Current skill level — determines cook time.
  final SkillLevel skill;

  /// Cook time in seconds for this chef's current skill.
  int get cookTimeSeconds => skill.cookTimeSeconds;

  /// Returns a copy with the skill upgraded to the next level.
  /// Returns unchanged if already at max.
  ChefProfile upgraded() {
    final next = skill.next;
    if (next == null) return this;
    return ChefProfile(name: name, skill: next);
  }

  /// Returns a copy with the given fields replaced.
  ChefProfile copyWith({
    String? name,
    SkillLevel? skill,
  }) {
    return ChefProfile(
      name: name ?? this.name,
      skill: skill ?? this.skill,
    );
  }

  @override
  String toString() => 'ChefProfile($name, ${skill.label})';
}
