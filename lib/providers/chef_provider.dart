import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chef_profile.dart';
import '../models/skill_level.dart';

/// Single chef (Ken) state management.
class ChefNotifier extends Notifier<ChefProfile> {
  @override
  ChefProfile build() => ChefProfile.ken;

  /// Upgrade Ken to the next skill level.
  /// Returns true if the upgrade was applied.
  bool upgrade() {
    final next = state.skillLevel.next;
    if (next == null) return false;
    state = state.copyWith(skillLevel: next);
    return true;
  }

  void setSkillLevel(SkillLevel level) {
    state = state.copyWith(skillLevel: level);
  }
}

final chefProvider = NotifierProvider<ChefNotifier, ChefProfile>(
  ChefNotifier.new,
);
