import 'package:flame_behaviors/flame_behaviors.dart';

import '../../../models/customer_order.dart';
import 'chef_entity.dart';
import 'chef_state.dart';

/// Drives the chef's cooking state machine.
///
/// State flow: available → cooking (progress 0→1) → plating (1 s) → available
class CookBehavior extends Behavior<ChefEntity> {
  ChefState state = ChefState.available;

  double _cookProgress = 0.0;
  double _platingTimer = 0.0;
  CustomerOrder? _currentOrder;

  static const _platingDuration = 1.0;

  /// Visible progress for [ProgressBarComponent] (0.0–1.0).
  double get cookProgress => _cookProgress;

  ChefState get chefState => state;

  @override
  void update(double dt) {
    switch (state) {
      case ChefState.available:
        final next = parent.nextOrder();
        if (next != null) {
          _currentOrder = next;
          _cookProgress = 0.0;
          state = ChefState.cooking;
        }

      case ChefState.cooking:
        if (_currentOrder == null) {
          state = ChefState.available;
          return;
        }
        _cookProgress += dt / parent.cookTimeSeconds;
        if (_cookProgress >= 1.0) {
          _cookProgress = 1.0;
          state = ChefState.plating;
          _platingTimer = 0.0;
        }

      case ChefState.plating:
        _platingTimer += dt;
        if (_platingTimer >= _platingDuration) {
          _serveOrder();
          state = ChefState.available;
          _currentOrder = null;
          _cookProgress = 0.0;
        }

      case ChefState.resting:
        break;
    }
  }

  void _serveOrder() {
    final order = _currentOrder;
    if (order == null) return;
    parent.onOrderServed(order);
  }
}
