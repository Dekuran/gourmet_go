import 'dart:developer' as developer;

import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// All overlay identifiers used by the Flame [GameWidget].
///
/// Each overlay maps to a Flutter widget builder registered in
/// [GameWidget.overlayBuilderMap] inside `main.dart`.
enum GameOverlay {
  /// FTUE sous-chef dialogue panel.
  dialogue,

  /// Camera capture screen (photo → recognition).
  camera,

  /// Dish card reveal with 3D model.
  dishReveal,

  /// Menu board grid + 3D viewer.
  menuBoard,

  /// Heads-up display: cash, day, star rating.
  hud,

  /// Starter bowl picker (FTUE fallback when camera unavailable).
  starterPicker,

  /// API test dashboard — preserved from pre-Flame build.
  apiTest,
}

/// Root-level Flame game for Gourmet GO.
///
/// Manages scene transitions via [World] swapping and
/// Flutter overlay toggling for UI-heavy panels (camera, menus,
/// dialogue). Uses [FlameGame] with a fixed-resolution camera.
class GourmetGoGame extends FlameGame {
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
      'GourmetGoGame loaded — viewport 390×844',
      name: 'gourmet_go.game',
    );

    // Start with a placeholder world; FTUE or map scene will
    // replace this once services are initialised in main.dart.
    world = _SplashWorld();
    currentScene = 'splash';
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

/// Minimal placeholder world shown during app boot.
///
/// Displays nothing — the real scene is swapped in once
/// async services finish initialisation.
class _SplashWorld extends World {
  @override
  Future<void> onLoad() async {
    developer.log(
      'SplashWorld loaded (waiting for scene switch)',
      name: 'gourmet_go.game',
    );
  }
}
