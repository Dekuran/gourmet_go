import 'dart:developer' as developer;

import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';

import '../services/ftue_service.dart';
import 'scenes/ftue_scene.dart';
import 'scenes/map_scene.dart';
import 'scenes/shop_scene.dart';

/// All overlay identifiers used by the Flame [GameWidget].
///
/// Each overlay maps to a Flutter widget builder registered in
/// [RiverpodAwareGameWidget.overlayBuilderMap] inside `main.dart`.
enum GameOverlay {
  /// FTUE sous-chef dialogue panel.
  ftue,

  /// Camera capture screen (photo → recognition).
  camera,

  /// Dish card reveal with 3D model.
  dishReveal,

  /// Menu board grid + 3D viewer.
  menuBoard,

  /// Heads-up display: cash, day, star rating.
  hud,

  /// Shop / kitchen overlay — menu, service start, travel.
  shop,

  /// Starter bowl picker (FTUE fallback when camera unavailable).
  starterPicker,

  /// Map region info bottom sheet.
  mapInfo,

  /// Day summary + star rating overlay.
  daySummary,

  /// Chef upgrade overlay.
  upgrade,

  /// Sous chef contextual commentary bubble.
  sousChefBubble,

  /// API test dashboard — preserved from pre-Flame build.
  apiTest,
}

/// Root-level Flame game for Gourmet GO.
///
/// Uses [RiverpodGameMixin] so that Flame components can access
/// Riverpod providers via [RiverpodComponentMixin.ref]. The game
/// manages scene transitions via [World] swapping and Flutter
/// overlay toggling for UI-heavy panels (camera, menus, dialogue).
///
/// Must be used with [RiverpodAwareGameWidget] in `main.dart`.
class GourmetGoGame extends FlameGame with RiverpodGameMixin {
  GourmetGoGame()
      : super(
          camera: CameraComponent.withFixedResolution(
            width: 390,
            height: 844,
          ),
        );

  /// Current scene name, for debugging / analytics.
  String currentScene = 'none';

  @override
  Color backgroundColor() => const Color(0xFF0F0F1A);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    developer.log(
      'GourmetGoGame loaded — viewport 390×844, Riverpod bridged',
      name: 'gourmet_go.game',
    );

    // Check FTUE state and start the appropriate scene.
    final ftueComplete = await FtueService.instance.isComplete();

    if (ftueComplete) {
      // Returning player → go straight to shop (restaurant kitchen).
      developer.log('FTUE complete — starting ShopScene', name: 'gourmet_go.game');
      world = ShopScene();
      currentScene = 'shop';
    } else {
      // First launch → start FTUE (dark kitchen + sous chef dialogue).
      developer.log('First launch — starting FtueScene', name: 'gourmet_go.game');
      world = FtueScene();
      currentScene = 'ftue';
    }
  }

  // ─── Scene management ───

  /// Replace the current [World] with a new scene component.
  ///
  /// Removes all active overlays first to prevent stale UI.
  void switchScene(Component newWorld, String sceneName) {
    overlays.clear();
    world = newWorld as World;
    currentScene = sceneName;
    developer.log(
      'Scene → $sceneName',
      name: 'gourmet_go.game',
    );
  }

  // ─── Overlay helpers ───

  /// Show a named overlay (type-safe via [GameOverlay] enum).
  void showOverlay(GameOverlay overlay) {
    overlays.add(overlay.name);
  }

  /// Hide a named overlay.
  void hideOverlay(GameOverlay overlay) {
    overlays.remove(overlay.name);
  }

  /// Whether an overlay is currently visible.
  bool isOverlayActive(GameOverlay overlay) =>
      overlays.isActive(overlay.name);
}

