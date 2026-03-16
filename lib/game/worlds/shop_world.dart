import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/dish.dart';
import '../../providers/game_providers.dart';
import '../gourmet_go_game.dart';
import '../components/chef/chef_entity.dart';
import '../components/customer/customer_queue_component.dart';
import '../components/kitchen/service_timer_component.dart';
import '../components/kitchen/order_dispatcher.dart';

/// The service-day world: kitchen background, chef, customer queue, timer.
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

    // Colored background rectangle (placeholder for kitchen art).
    final bg = RectangleComponent(
      size: game.size,
      paint: Paint()..color = const Color(0xFF1A0F08),
    );
    add(bg);

    orderDispatcher = OrderDispatcher();
    chef = ChefEntity(game: game, dispatcher: orderDispatcher);
    serviceTimer = ServiceTimerComponent(game: game);
    customerQueue = CustomerQueueComponent(
      game: game,
      dispatcher: orderDispatcher,
    );

    await addAll([orderDispatcher, chef, serviceTimer, customerQueue]);
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
