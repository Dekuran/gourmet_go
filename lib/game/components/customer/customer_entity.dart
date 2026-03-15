import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:flame_riverpod/flame_riverpod.dart';

import '../../../models/customer_order.dart';
import '../../../providers/customer_queue_provider.dart';
import '../kitchen/order_dispatcher.dart';
import '../kitchen/progress_bar_component.dart';
import 'customer_state.dart';
import 'speech_bubble_component.dart';
import 'wait_behavior.dart';

/// A mechanical customer: a dish order + patience countdown.
///
/// No names or personality — purely a timer-driven order ticket.
class CustomerEntity extends PositionComponent
    with RiverpodComponentMixin, EntityMixin {
  CustomerEntity({
    required this.order,
    required this.dispatcher,
    required Vector2 slotPosition,
  })  : customerState = CustomerState.waiting,
        super(position: slotPosition, size: Vector2(80, 100));

  final CustomerOrder order;
  final OrderDispatcher dispatcher;
  CustomerState customerState;

  late ProgressBarComponent _patienceBar;
  late WaitBehavior _waitBehavior;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Placeholder customer body (grey rectangle).
    final body = RectangleComponent(
      size: size,
      paint: Paint()..color = const Color(0xFF7B8FA1),
    );

    // Patience bar at bottom of body.
    _patienceBar = ProgressBarComponent(
      position: Vector2(0, size.y + 4),
      size: Vector2(size.x, 6),
      fillColor: const Color(0xFF4CAF50),
      bgColor: const Color(0xFF555555),
    );

    final bubble = SpeechBubbleComponent(order: order, customer: this);
    _waitBehavior = WaitBehavior();

    await addAll([body, _patienceBar, bubble, _waitBehavior]);
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
