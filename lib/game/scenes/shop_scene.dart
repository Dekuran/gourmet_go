import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../services/game_asset_service.dart';
import '../gourmet_go_game.dart';

/// Shop / kitchen scene — the restaurant interior where service happens.
///
/// Shows the kitchen background with warm lighting (no darkness overlay).
/// The HUD overlay is shown on top for cash, day, and phase display.
///
/// This is the scene used after the FTUE completes and the player
/// enters the restaurant with their first dish on the menu.
class ShopScene extends World with HasGameReference<GourmetGoGame> {
  @override
  Future<void> onLoad() async {
    developer.log('ShopScene: loading', name: 'gourmet_go.scene');

    // Kitchen background — fills the viewport
    final bgImage = await GameAssetService().loadFlameImage(
      GameAssetService.kitchenBg,
    );

    if (bgImage != null) {
      final kitchenBg = SpriteComponent(
        sprite: Sprite(bgImage),
        size: Vector2(390, 844),
        position: Vector2(-195, -422), // centred in camera
      );
      add(kitchenBg);
    }

    // Warm ambient tint — slight orange glow for the shop atmosphere
    final warmTint = Paint()..color = const Color(0x15FF6600); // ~8% orange
    final tintOverlay = RectangleComponent(
      size: Vector2(390, 844),
      position: Vector2(-195, -422),
      paint: warmTint,
      priority: 5,
    );
    add(tintOverlay);

    developer.log('ShopScene: loaded', name: 'gourmet_go.scene');

    // Show HUD overlay for the shop
    game.showOverlay(GameOverlay.hud);
  }
}
