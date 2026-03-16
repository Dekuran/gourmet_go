import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';

import '../../../providers/customer_queue_provider.dart';
import '../../../providers/game_providers.dart';
import '../../gourmet_go_game.dart';
import '../kitchen/order_dispatcher.dart';
import 'customer_entity.dart';

/// Manages timed spawning of mechanical [CustomerEntity] instances.
///
/// Spawns up to 8 customers per day, roughly every 30 seconds.
///
/// Layout: customers fill a 2-column grid on the LEFT side of the
/// landscape viewport (960×540, origin at centre).
class CustomerQueueComponent extends Component with RiverpodComponentMixin {
  CustomerQueueComponent({required this.game, required this.dispatcher});

  static const _spawnInterval = 30.0;
  static const _maxCustomers = 8;
  static const _slotsPerColumn = 4;
  static const _slotWidth = 85.0;
  static const _slotHeight = 110.0;

  final GourmetGoGame game;
  final OrderDispatcher dispatcher;

  double _spawnTimer = 0;
  int _spawned = 0;

  final List<CustomerEntity> _active = [];

  @override
  void update(double dt) {
    if (_spawned >= _maxCustomers) return;

    _spawnTimer += dt;
    if (_spawnTimer >= _spawnInterval) {
      _spawnTimer = 0;
      _trySpawn();
    }
  }

  void _trySpawn() {
    final menu = ref.read(menuProvider);
    final order = ref.read(customerQueueProvider.notifier).spawnCustomer(menu);
    if (order == null) return;

    final slot = _slotPosition(_spawned);
    final entity = CustomerEntity(
      order: order,
      dispatcher: dispatcher,
      slotPosition: slot,
    );

    _active.add(entity);
    parent?.add(entity);
    _spawned++;
  }

  /// Compute a grid position using world-centred coordinates.
  ///
  /// Two columns of 4 on the left side of the 960×540 viewport.
  /// Column 1: x ≈ -420, Column 2: x ≈ -335
  /// Rows start at y ≈ -180 (above centre).
  Vector2 _slotPosition(int index) {
    final col = index ~/ _slotsPerColumn;
    final row = index % _slotsPerColumn;
    const gridLeft = -420.0;
    const gridTop = -180.0;
    return Vector2(
      gridLeft + col * _slotWidth,
      gridTop + row * _slotHeight,
    );
  }

  void reset() {
    for (final e in _active) {
      e.removeFromParent();
    }
    _active.clear();
    _spawned = 0;
    _spawnTimer = 0;
    ref.read(customerQueueProvider.notifier).clear();
  }
}
