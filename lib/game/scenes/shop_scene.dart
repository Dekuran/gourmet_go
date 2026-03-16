import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../services/game_asset_service.dart';
import '../gourmet_go_game.dart';

/// Shop / kitchen scene — the restaurant interior where service happens.
///
/// Shows the kitchen background with warm lighting.
/// The shop overlay (Flutter) is shown on top for the full kitchen UI.
///
/// This is the scene used after the FTUE completes and the player
/// enters the restaurant with their first dish on the menu.
class ShopScene extends World with HasGameReference<GourmetGoGame> {
  @override
  Future<void> onLoad() async {
    developer.log('ShopScene: loading', name: 'gourmet_go.scene');

    // Use the game camera's viewport size for proper scaling
    final viewW = game.camera.viewport.size.x;
    final viewH = game.camera.viewport.size.y;
    final halfW = viewW / 2;
    final halfH = viewH / 2;

    // Kitchen background — fills the viewport
    final bgImage = await GameAssetService().loadFlameImage(
      GameAssetService.kitchenBg,
    );

    if (bgImage != null) {
      final kitchenBg = SpriteComponent(
        sprite: Sprite(bgImage),
        size: Vector2(viewW, viewH),
        position: Vector2(-halfW, -halfH), // centred in camera
      );
      add(kitchenBg);
    }

    // Warm ambient tint — slight orange glow for the shop atmosphere
    final warmTint = Paint()..color = const Color(0x15FF6600); // ~8% orange
    final tint = RectangleComponent(
      size: Vector2(viewW, viewH),
      position: Vector2(-halfW, -halfH),
      paint: warmTint,
      priority: 5,
    );
    add(tint);

    developer.log('ShopScene: loaded (${viewW}x$viewH)',
        name: 'gourmet_go.scene');

    // Show the shop overlay (kitchen menu + actions)
    game.showOverlay(GameOverlay.shop);
  }
}
