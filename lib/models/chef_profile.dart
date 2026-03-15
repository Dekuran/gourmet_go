import 'skill_level.dart';

/// Profile for the single chef (Ken).
///
/// Ken starts at [SkillLevel.trained] (45s per bowl) and can be
/// upgraded up to [SkillLevel.master] (12s per bowl).
class ChefProfile {
  final String name;
  final SkillLevel skillLevel;

  const ChefProfile({
    required this.name,
    required this.skillLevel,
  });

  int get cookTimeSeconds => skillLevel.cookTimeSeconds;

  ChefProfile copyWith({String? name, SkillLevel? skillLevel}) =>
      ChefProfile(
        name: name ?? this.name,
        skillLevel: skillLevel ?? this.skillLevel,
      );

  static const ChefProfile ken = ChefProfile(
    name: 'Ken',
    skillLevel: SkillLevel.trained,
  );
}
