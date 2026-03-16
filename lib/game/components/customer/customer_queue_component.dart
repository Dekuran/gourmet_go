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
class CustomerQueueComponent extends Component with RiverpodComponentMixin {
  CustomerQueueComponent({required this.game, required this.dispatcher});

  static const _spawnInterval = 30.0;
  static const _maxCustomers = 8;
  static const _slotsPerRow = 4;
  static const _slotWidth = 85.0;
  static const _slotStartX = 20.0;
  static const _slotStartY = 60.0;

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

  Vector2 _slotPosition(int index) {
    final row = index ~/ _slotsPerRow;
    final col = index % _slotsPerRow;
    return Vector2(
      _slotStartX + col * _slotWidth,
      _slotStartY + row * 120.0,
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
