import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../../services/game_asset_service.dart';
import '../gourmet_go_game.dart';

/// FTUE intro scene — dark kitchen slowly illuminating.
///
/// Displays the kitchen background sprite with a darkness overlay
/// that fades out during the sous chef monologue. The sous chef
/// portrait is shown via the [GameOverlay.ftue] Flutter overlay.
///
/// Flow: FtueScene loads → shows ftue overlay → overlay drives
/// dialogue + TTS → overlay signals transition to camera.
class FtueScene extends World with HasGameReference<GourmetGoGame> {
  late SpriteComponent _kitchenBg;
  late RectangleComponent _darkness;

  @override
  Future<void> onLoad() async {
    developer.log('FtueScene: loading', name: 'gourmet_go.scene');

    final viewW = game.camera.viewport.size.x;
    final viewH = game.camera.viewport.size.y;
    final halfW = viewW / 2;
    final halfH = viewH / 2;

    // Kitchen background — fills the viewport
    final bgImage = await GameAssetService().loadFlameImage(
      GameAssetService.kitchenBg,
    );

    if (bgImage != null) {
      _kitchenBg = SpriteComponent(
        sprite: Sprite(bgImage),
        size: Vector2(viewW, viewH),
        position: Vector2(-halfW, -halfH),
      );
      add(_kitchenBg);
    }

    // Dark overlay — starts at 85% opacity, fades during dialogue
    final darkPaint = Paint()..color = const Color(0xD9000000); // ~85%
    _darkness = RectangleComponent(
      size: Vector2(viewW, viewH),
      position: Vector2(-halfW, -halfH),
      paint: darkPaint,
      priority: 10,
    );
    add(_darkness);

    developer.log(
      'FtueScene: loaded (${viewW}x$viewH), showing overlay',
      name: 'gourmet_go.scene',
    );

    // Show the FTUE dialogue overlay
    game.showOverlay(GameOverlay.ftue);
  }

  /// Gradually reduce the darkness overlay opacity.
  ///
  /// Called by the FTUE overlay as dialogue progresses.
  /// [targetOpacity] should be 0.0–1.0.
  void setDarknessOpacity(double targetOpacity) {
    _darkness.add(
      OpacityEffect.to(
        targetOpacity,
        EffectController(duration: 1.5),
      ),
    );
  }

  /// Flash the kitchen to full brightness.
  ///
  /// Called when the player is about to transition to camera.
  void flashReveal() {
    setDarknessOpacity(0.0);
  }
}
