import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dish.dart';

/// Dishes currently on the player's menu.
class MenuNotifier extends Notifier<List<Dish>> {
  @override
  List<Dish> build() => const [];

  void addDish(Dish dish) {
    if (state.any((d) => d.varietyId == dish.varietyId)) return;
    state = [...state, dish];
  }

  void removeDish(String varietyId) {
    state = state.where((d) => d.varietyId != varietyId).toList();
  }

  void updatePrice(String varietyId, int price) {
    state = [
      for (final d in state)
        if (d.varietyId == varietyId) d.copyWith(price: price) else d,
    ];
  }

  /// Seed with starter bowls when menu is empty.
  void seedStarterBowls() {
    if (state.isNotEmpty) return;
    state = List.of(Dish.starterBowls);
  }
}

final menuProvider = NotifierProvider<MenuNotifier, List<Dish>>(
  MenuNotifier.new,
);
