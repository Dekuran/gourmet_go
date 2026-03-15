import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/dish.dart';
import 'debug_logger.dart';

/// Tracks FTUE (First-Time User Experience) progress via SharedPreferences.
///
/// The FTUE is a linear flow:
///   1. Dark-kitchen sous-chef monologue
///   2. Camera opens — player photographs their first ramen bowl
///   3. Dish card reveal
///   4. Transition to map
///
/// This service persists completion state so the FTUE only plays once.
/// It also stores the first dish created during FTUE for reference in
/// the day summary and sous-chef commentary.
///
/// **Riverpod integration:**
/// The read-side is [ftueCompleteProvider] in `game_providers.dart`
/// (a [FutureProvider<bool>]). This service is the write-side.
/// After calling [markComplete], invalidate [ftueCompleteProvider]
/// so watchers pick up the change:
/// ```dart
/// ref.invalidate(ftueCompleteProvider);
/// ```
///
/// See [ftue_implementation_plan.md §2B](../../docs/ftue_implementation_plan.md).
class FtueService {
  FtueService._();
  static final FtueService instance = FtueService._();

  static final _log = DebugLogger.instance;

  // SharedPreferences keys
  static const _keyComplete = 'ftue_complete';
  static const _keyStep = 'ftue_step';
  static const _keyFirstDish = 'ftue_first_dish';

  /// Whether the FTUE has been completed.
  ///
  /// Returns `true` after [markComplete] has been called at least once.
  Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyComplete) ?? false;
  }

  /// Whether this is the player's first launch (FTUE not yet completed).
  Future<bool> isFirstLaunch() async {
    final complete = await isComplete();
    return !complete;
  }

  /// Mark the FTUE as complete. Call this at the end of the FTUE flow
  /// (after the first dish is added to the menu and the map opens).
  ///
  /// After calling this, remember to invalidate [ftueCompleteProvider]:
  /// ```dart
  /// ref.invalidate(ftueCompleteProvider);
  /// ```
  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyComplete, true);
    _log.logSuccess('FtueService', 'markComplete', 'FTUE marked as complete');
  }

  /// Reset the FTUE flag (for development/testing).
  ///
  /// Clears all FTUE-related SharedPreferences keys.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyComplete);
    await prefs.remove(_keyStep);
    await prefs.remove(_keyFirstDish);
    _log.logInfo('FtueService', 'FTUE state reset');
  }

  // ─── Step Tracking ─────────────────────────────────────────────────────────

  /// Save the current FTUE step so the flow can resume if interrupted.
  ///
  /// Steps are identified by [FtueStep] enum values.
  Future<void> saveStep(FtueStep step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStep, step.name);
    _log.logInfo('FtueService', 'Step saved: ${step.name}');
  }

  /// Get the last saved FTUE step, or [FtueStep.intro] if none saved.
  ///
  /// Use this on app launch to resume the FTUE from where the player left off.
  Future<FtueStep> getLastStep() async {
    final prefs = await SharedPreferences.getInstance();
    final stepName = prefs.getString(_keyStep);
    if (stepName == null) return FtueStep.intro;
    return FtueStep.values.firstWhere(
      (s) => s.name == stepName,
      orElse: () => FtueStep.intro,
    );
  }

  // ─── First Dish ────────────────────────────────────────────────────────────

  /// Store the first dish created during the FTUE.
  ///
  /// Serialised as JSON to SharedPreferences. Retrieved later for
  /// sous-chef commentary and day-summary references.
  Future<void> saveFirstDish(Dish dish) async {
    final prefs = await SharedPreferences.getInstance();
    final json = <String, dynamic>{
      'variety_id': dish.varietyId,
      'ramen_name': dish.name,
      'regional_style': dish.regionalStyle,
      'broth_base': dish.brothBase,
      'rarity_tier': dish.rarityTier,
      'regional_lore': dish.regionalLore,
      'confidence_0_to_1': dish.confidence,
    };
    await prefs.setString(_keyFirstDish, jsonEncode(json));
    _log.logSuccess(
      'FtueService',
      'saveFirstDish',
      '${dish.name} (${dish.regionalStyle})',
    );
  }

  /// Retrieve the first dish created during the FTUE.
  ///
  /// Returns `null` if no first dish has been saved yet.
  Future<Dish?> getFirstDish() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFirstDish);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return Dish.fromIdentification(json);
    } catch (e) {
      _log.logError('FtueService', 'getFirstDish', 'Parse error: $e');
      return null;
    }
  }
}

/// Steps in the FTUE flow.
///
/// Used by [FtueService.saveStep] / [FtueService.getLastStep] to persist
/// progress so the FTUE can resume if the app is killed mid-flow.
enum FtueStep {
  /// Sous-chef monologue in the dark kitchen.
  intro,

  /// Camera is open — player is photographing their first bowl.
  camera,

  /// Dish card reveal animation.
  dishReveal,

  /// Transition to the map — FTUE is almost done.
  mapTransition,

  /// FTUE complete — should not normally be saved (use [FtueService.markComplete]).
  complete,
}
