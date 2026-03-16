import 'dart:collection';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:flame_riverpod/flame_riverpod.dart';

import '../../../models/customer_order.dart';
import '../../../providers/customer_queue_provider.dart';
import '../../../providers/game_providers.dart';
import '../../gourmet_go_game.dart';
import '../kitchen/order_dispatcher.dart';
import '../kitchen/progress_bar_component.dart';
import 'chef_state.dart';
import 'cook_behavior.dart';

/// The single chef entity (Ken) on the kitchen canvas.
///
/// Maintains a cook queue and drives [CookBehavior] for order processing.
/// Earns cash via [cashProvider] when each bowl is served.
class ChefEntity extends PositionComponent
    with RiverpodComponentMixin, EntityMixin {
  ChefEntity({required this.game, required this.dispatcher})
      : super(size: Vector2(80, 120));

  final GourmetGoGame game;
  final OrderDispatcher dispatcher;

  final Queue<CustomerOrder> _queue = Queue();
  late CookBehavior _cookBehavior;
  late ProgressBarComponent _progressBar;

  int get cookTimeSeconds => ref.read(chefCookTimeProvider);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Position chef in the lower-center area.
    position = Vector2(game.size.x / 2 - 40, game.size.y - 280);

    // Placeholder body rectangle.
    final body = RectangleComponent(
      size: size,
      paint: Paint()..color = const Color(0xFFE8A040),
    );

    // Progress bar sits just below the chef body.
    _progressBar = ProgressBarComponent(
      position: Vector2(0, size.y + 6),
      size: Vector2(size.x, 8),
    );

    _cookBehavior = CookBehavior();

    // Wire dispatcher to this chef.
    dispatcher.chef = this;

    await addAll([body, _progressBar, _cookBehavior]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _progressBar.progress = _cookBehavior.cookProgress;
  }

  /// Add an order to the cook queue.
  void enqueue(CustomerOrder order) {
    ref.read(customerQueueProvider.notifier).markCooking(order);
    _queue.addLast(order);
  }

  /// Called by [CookBehavior] to retrieve the next queued order.
  CustomerOrder? nextOrder() => _queue.isNotEmpty ? _queue.removeFirst() : null;

  /// Called by [CookBehavior] when an order is fully cooked and plated.
  void onOrderServed(CustomerOrder order) {
    ref.read(cashProvider.notifier).earn(order.dish.effectivePrice);
    ref.read(customerQueueProvider.notifier).markServed(order);
  }

  /// Reset state for a new service day.
  void reset() {
    _queue.clear();
    _cookBehavior.state = ChefState.available;
    _progressBar.progress = 0;
  }
}
