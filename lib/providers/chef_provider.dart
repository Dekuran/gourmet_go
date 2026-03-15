import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chef_profile.dart';
import '../models/skill_level.dart';

/// Single chef (Ken) state management.
class ChefNotifier extends Notifier<ChefProfile> {
  @override
  ChefProfile build() => ChefProfile(name: 'Ken');

  /// Upgrade Ken to the next skill level.
  /// Returns true if the upgrade was applied.
  bool upgrade() {
    final next = state.skill.next;
    if (next == null) return false;
    state = state.copyWith(skill: next);
    return true;
  }

  void setSkillLevel(SkillLevel level) {
    state = state.copyWith(skill: level);
  }
}

final chefProvider = NotifierProvider<ChefNotifier, ChefProfile>(
  ChefNotifier.new,
);

/// Current cook time in seconds, derived from the chef's skill level.
final chefCookTimeProvider = Provider<int>(
  (ref) => ref.watch(chefProvider).cookTimeSeconds,
);
