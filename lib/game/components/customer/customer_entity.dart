import 'dart:developer' as developer;
import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/painting.dart' show TextStyle;

import '../../../models/customer_order.dart';
import '../../../providers/customer_queue_provider.dart';
import '../../../services/game_asset_service.dart' as assets;
import '../kitchen/order_dispatcher.dart';
import '../kitchen/progress_bar_component.dart';
import 'customer_state.dart';
import 'speech_bubble_component.dart';
import 'wait_behavior.dart';

/// A mechanical customer: a dish order + patience countdown.
///
/// Uses actual customer sprites when available, with a coloured
/// rectangle fallback. Speech bubble shows the order and is tappable
/// to assign the order to the chef.
class CustomerEntity extends PositionComponent
    with RiverpodComponentMixin, EntityMixin {
  CustomerEntity({
    required this.order,
    required this.dispatcher,
    required Vector2 slotPosition,
  })  : customerState = CustomerState.waiting,
        super(position: slotPosition, size: Vector2(70, 90));

  final CustomerOrder order;
  final OrderDispatcher dispatcher;
  CustomerState customerState;

  late ProgressBarComponent _patienceBar;
  late WaitBehavior _waitBehavior;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Try loading customer sprite.
    final customerIndex = order.hashCode % 6;
    final spritePath = assets.GameAssetService.customerSprite(
      customerIndex,
      assets.CustomerState.waiting,
    );
    final img = await assets.GameAssetService().loadFlameImage(spritePath);

    if (img != null) {
      add(SpriteComponent(
        sprite: Sprite(img),
        size: size,
      ));
      developer.log('CustomerEntity: sprite loaded ($spritePath)',
          name: 'gourmet_go.customer');
    } else {
      // Fallback coloured rectangle.
      developer.log('CustomerEntity: sprite failed, using fallback',
          name: 'gourmet_go.customer');
      final body = RectangleComponent(
        size: size,
        paint: Paint()..color = const Color(0xFF7B8FA1),
      );
      add(body);

      // Customer emoji indicator.
      add(TextComponent(
        text: '🧑',
        position: Vector2(size.x / 2, size.y / 2 - 8),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(fontSize: 20),
        ),
      ));
    }

    // Patience bar at bottom of body.
    _patienceBar = ProgressBarComponent(
      position: Vector2(0, size.y + 4),
      size: Vector2(size.x, 6),
      fillColor: const Color(0xFF4CAF50),
      bgColor: const Color(0xFF555555),
    );

    final bubble = SpeechBubbleComponent(order: order, customer: this);
    _waitBehavior = WaitBehavior();

    await addAll([_patienceBar, bubble, _waitBehavior]);
  }

  void updatePatienceBar(double ratio) => _patienceBar.progress = ratio;

  /// Called when the player taps the speech bubble.
  void onBubbleTapped() {
    if (customerState != CustomerState.waiting) return;
    dispatcher.assign(order, this);
  }

  /// Called by [OrderDispatcher] after successfully assigning the order.
  void markAssigned() {
    customerState = CustomerState.assigned;
    ref.read(customerQueueProvider.notifier).markCooking(order);
  }

  /// Called when patience runs out before the order is assigned.
  void onPatienceExpired() {
    if (customerState != CustomerState.waiting) return;
    customerState = CustomerState.left;
    ref.read(customerQueueProvider.notifier).markExpired(order);
    removeFromParent();
  }

  /// Called externally when this customer's bowl has been served.
  void onServed() {
    customerState = CustomerState.served;
    removeFromParent();
  }
}
