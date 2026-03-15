import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/skill_level.dart';
import 'cash_provider.dart';
import 'chef_provider.dart';

/// Whether the chef can afford the next upgrade.
final canUpgradeProvider = Provider<bool>((ref) {
  final chef = ref.watch(chefProvider);
  final cash = ref.watch(cashProvider);
  final next = chef.skill.next;
  if (next == null) return false;
  return cash >= next.upgradeCost;
});

/// Info about the next available upgrade.
final nextUpgradeInfoProvider =
    Provider<({String label, int cost, SkillLevel level})?>(
  (ref) {
    final chef = ref.watch(chefProvider);
    final next = chef.skill.next;
    if (next == null) return null;
    return (label: next.label, cost: next.upgradeCost, level: next);
  },
);
