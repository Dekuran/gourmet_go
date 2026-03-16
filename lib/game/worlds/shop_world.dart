import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/dish.dart';
import '../../providers/game_providers.dart';
import '../../services/game_asset_service.dart';
import '../gourmet_go_game.dart';
import '../components/chef/chef_entity.dart';
import '../components/customer/customer_queue_component.dart';
import '../components/kitchen/service_timer_component.dart';
import '../components/kitchen/order_dispatcher.dart';

/// The service-day world: kitchen background, chef, customer queue, timer.
///
/// Uses the camera's fixed-resolution viewport (960×540) centred at (0, 0).
/// All child positions use world coordinates:
///   top-left = (-480, -270),  bottom-right = (480, 270).
class ShopWorld extends World {
  ShopWorld({required this.game});

  final GourmetGoGame game;

  late ChefEntity chef;
  late ServiceTimerComponent serviceTimer;
  late CustomerQueueComponent customerQueue;
  late OrderDispatcher orderDispatcher;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    developer.log('ShopWorld: loading', name: 'gourmet_go.scene');

    // Viewport dimensions from the fixed-resolution camera.
    final viewW = game.camera.viewport.size.x;
    final viewH = game.camera.viewport.size.y;
    final halfW = viewW / 2;
    final halfH = viewH / 2;

    developer.log('ShopWorld: viewport ${viewW}x$viewH', name: 'gourmet_go.scene');

    // ── Kitchen background image ──
    final bgImage = await GameAssetService().loadFlameImage(
      GameAssetService.kitchenBg,
    );

    if (bgImage != null) {
      final kitchenBg = SpriteComponent(
        sprite: Sprite(bgImage),
        size: Vector2(viewW, viewH),
        position: Vector2(-halfW, -halfH),
      );
      add(kitchenBg);
      developer.log('ShopWorld: kitchen_bg loaded', name: 'gourmet_go.scene');
    } else {
      // Fallback warm-toned rectangle if sprite fails to load.
      developer.log('ShopWorld: kitchen_bg failed, using fallback',
          name: 'gourmet_go.scene');
      final bg = RectangleComponent(
        size: Vector2(viewW, viewH),
        position: Vector2(-halfW, -halfH),
        paint: Paint()..color = const Color(0xFF3D2B1F), // warm brown
      );
      add(bg);
    }

    // Warm ambient tint for shop atmosphere.
    final warmTint = Paint()..color = const Color(0x15FF6600);
    final tint = RectangleComponent(
      size: Vector2(viewW, viewH),
      position: Vector2(-halfW, -halfH),
      paint: warmTint,
      priority: 5,
    );
    add(tint);

    // ── Gameplay components ──
    orderDispatcher = OrderDispatcher();
    chef = ChefEntity(game: game, dispatcher: orderDispatcher);
    serviceTimer = ServiceTimerComponent(game: game);
    customerQueue = CustomerQueueComponent(
      game: game,
      dispatcher: orderDispatcher,
    );

    await addAll([orderDispatcher, chef, serviceTimer, customerQueue]);

    developer.log('ShopWorld: loaded', name: 'gourmet_go.scene');
  }

  @override
  void onMount() {
    super.onMount();
    // Seed menu with starter bowls so customers always have dishes to order.
    final menu = game.ref.read(menuProvider);
    if (menu.isEmpty) {
      final notifier = game.ref.read(menuProvider.notifier);
      for (final dish in Dish.starterBowls) {
        notifier.addDish(dish);
      }
    }
    // Set game phase so HUD shows service timer.
    game.ref.read(gamePhaseProvider.notifier).set(GamePhase.shop);
    game.showHud();
  }

  @override
  void onRemove() {
    game.hideHud();
    super.onRemove();
  }

  /// Reset world state for a new service day.
  void reset() {
    serviceTimer.reset();
    customerQueue.reset();
    chef.reset();
  }

  void pauseTimer() => serviceTimer.pause();
  void resumeTimer() => serviceTimer.resume();
}
