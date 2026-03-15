import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chef_profile.dart';
import '../models/dish.dart';
import '../models/region.dart';

// ─── Game Phase ───

/// High-level game phase — determines which World is active.
enum GamePhase {
  /// First-time user experience (sous chef monologue + first photo).
  ftue,

  /// Japan map — player selects a region.
  map,

  /// Ramen shop — service day in progress.
  shop,

  /// Day summary — rating breakdown + sous chef debrief.
  daySummary,

  /// Upgrade screen — spend cash on chef skill.
  upgrade,
}

/// Current high-level game phase.
class GamePhaseNotifier extends Notifier<GamePhase> {
  @override
  GamePhase build() => GamePhase.ftue;

  /// Transition to a new phase.
  void set(GamePhase phase) => state = phase;
}

final gamePhaseProvider = NotifierProvider<GamePhaseNotifier, GamePhase>(
  GamePhaseNotifier.new,
);

// ─── Cash ───

/// Cash balance notifier. Supports earn and spend operations.
class CashNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Add yen earned from serving a dish.
  void earn(int amount) => state = state + amount;

  /// Spend yen on an upgrade. Returns `false` if insufficient funds.
  bool spend(int amount) {
    if (state < amount) return false;
    state = state - amount;
    return true;
  }

  /// Reset to zero (new game).
  void reset() => state = 0;
}

/// Player's cash balance in yen.
final cashProvider = NotifierProvider<CashNotifier, int>(
  CashNotifier.new,
);

// ─── Chef ───

/// Single chef (Ken) — starts at Trained skill level.
class ChefNotifier extends Notifier<ChefProfile> {
  @override
  ChefProfile build() => ChefProfile(name: 'Ken');

  /// Upgrade the chef to the next skill level.
  void upgrade() => state = state.upgraded();

  /// Replace the chef profile entirely.
  void set(ChefProfile profile) => state = profile;
}

final chefProvider = NotifierProvider<ChefNotifier, ChefProfile>(
  ChefNotifier.new,
);

/// Cook time in seconds for the current chef skill level.
final chefCookTimeProvider = Provider<int>(
  (ref) => ref.watch(chefProvider).cookTimeSeconds,
);

// ─── Menu (discovered dishes) ───

/// Menu notifier — manages the player's discovered dish collection.
class MenuNotifier extends Notifier<List<Dish>> {
  @override
  List<Dish> build() => [];

  /// Add a newly discovered dish to the menu.
  void addDish(Dish dish) {
    // Prevent duplicates by varietyId.
    if (state.any((d) => d.varietyId == dish.varietyId)) return;
    state = [...state, dish];
  }

  /// Update a dish (e.g. when price or GLB URL arrives).
  void updateDish(String varietyId, Dish Function(Dish) updater) {
    state = [
      for (final d in state)
        if (d.varietyId == varietyId) updater(d) else d,
    ];
  }

  /// Remove a dish by varietyId.
  void removeDish(String varietyId) {
    state = state.where((d) => d.varietyId != varietyId).toList();
  }

  /// Clear all dishes (new game).
  void clear() => state = [];
}

/// The player's discovered dish collection.
final menuProvider = NotifierProvider<MenuNotifier, List<Dish>>(
  MenuNotifier.new,
);

// ─── Day ───

/// Current day number (1-indexed).
class DayNotifier extends Notifier<int> {
  @override
  int build() => 1;

  /// Advance to the next day.
  void advance() => state = state + 1;

  /// Reset to day 1.
  void reset() => state = 1;
}

final dayProvider = NotifierProvider<DayNotifier, int>(
  DayNotifier.new,
);

// ─── FTUE ───

/// Whether the FTUE has been completed, backed by SharedPreferences.
///
/// Returns `true` if FTUE is done, `false` on first launch.
final ftueCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('ftue_complete') ?? false;
});

// ─── Region Unlock State ───

/// Region unlock state — maps region IDs to unlock status.
///
/// A region is "discovered" when the player photographs a dish
/// from that region. It's "unlocked" when they can enter the shop.
/// For the prototype, discovering = unlocking.
class RegionUnlockNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {
        for (final r in Region.all) r.id: false,
      };

  /// Mark a region as unlocked.
  void unlock(String regionId) {
    state = {...state, regionId: true};
  }

  /// Whether a region is unlocked.
  bool isUnlocked(String regionId) => state[regionId] ?? false;

  /// Reset all regions to locked.
  void reset() {
    state = {for (final key in state.keys) key: false};
  }
}

/// Region unlock state for the 4 Japanese regions.
final regionUnlockProvider =
    NotifierProvider<RegionUnlockNotifier, Map<String, bool>>(
  RegionUnlockNotifier.new,
);
