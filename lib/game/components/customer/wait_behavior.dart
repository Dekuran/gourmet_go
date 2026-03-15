import 'package:flame_behaviors/flame_behaviors.dart';

import 'customer_entity.dart';
import 'customer_state.dart';

/// Counts down a customer's patience and removes them when it expires.
class WaitBehavior extends Behavior<CustomerEntity> {
  double _remaining = 0;
  late double _total;

  double get patienceRatio => _total > 0 ? (_remaining / _total).clamp(0, 1) : 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _remaining = parent.order.patienceSeconds;
    _total = _remaining;
  }

  @override
  void update(double dt) {
    if (parent.customerState != CustomerState.waiting) return;

    _remaining -= dt;
    parent.updatePatienceBar(patienceRatio);

    if (_remaining <= 0) {
      parent.onPatienceExpired();
    }
  }
}
