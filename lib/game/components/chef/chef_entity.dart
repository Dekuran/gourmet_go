import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:ui' hide TextStyle;

import 'package:flutter/painting.dart' show TextStyle, FontWeight;

import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:flame_riverpod/flame_riverpod.dart';

import '../../../models/customer_order.dart';
import '../../../providers/customer_queue_provider.dart';
import '../../../providers/game_providers.dart';
import '../../../services/game_asset_service.dart';
import '../../gourmet_go_game.dart';
import '../kitchen/order_dispatcher.dart';
import '../kitchen/progress_bar_component.dart';
import 'chef_state.dart';
import 'cook_behavior.dart';

/// The single chef entity (Ken) on the kitchen canvas.
///
/// Uses actual sprite assets when available, with a coloured rectangle
/// fallback. Positioned in the right-center of the landscape viewport.
///
/// Maintains a cook queue and drives [CookBehavior] for order processing.
/// Earns cash via [cashProvider] when each bowl is served.
class ChefEntity extends PositionComponent
    with RiverpodComponentMixin, EntityMixin {
  ChefEntity({required this.game, required this.dispatcher})
      : super(size: Vector2(96, 144));

  final GourmetGoGame game;
  final OrderDispatcher dispatcher;

  final Queue<CustomerOrder> _queue = Queue();
  late CookBehavior _cookBehavior;
  late ProgressBarComponent _progressBar;

  int get cookTimeSeconds => ref.read(chefCookTimeProvider);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Position chef in the right-center of the landscape viewport.
    // Viewport is 960×540 centred at origin → x: 160..480 is right side.
    position = Vector2(200, -size.y / 2);

    // Try loading the chef idle sprite.
    final chefImage = await GameAssetService().loadFlameImage(
      GameAssetService.chefIdleRed,
    );

    if (chefImage != null) {
      final sprite = SpriteComponent(
        sprite: Sprite(chefImage),
        size: size,
      );
      add(sprite);
      developer.log('ChefEntity: sprite loaded', name: 'gourmet_go.chef');
    } else {
      // Fallback coloured rectangle with label.
      developer.log('ChefEntity: sprite failed, using fallback',
          name: 'gourmet_go.chef');
      final body = RectangleComponent(
        size: size,
        paint: Paint()..color = const Color(0xFFE8A040),
      );
      add(body);

      // Chef label
      add(TextComponent(
        text: '👨‍🍳 Ken',
        position: Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: const Color(0xFF1A1A1A),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ));
    }

    // Progress bar sits just below the chef body.
    _progressBar = ProgressBarComponent(
      position: Vector2(0, size.y + 6),
      size: Vector2(size.x, 10),
    );

    _cookBehavior = CookBehavior();

    // Wire dispatcher to this chef.
    dispatcher.chef = this;

    await addAll([_progressBar, _cookBehavior]);
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
