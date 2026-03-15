import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_order.dart';
import '../models/dish.dart';

/// Manages the mechanical customer queue for the current service day.
class CustomerQueueNotifier extends Notifier<List<CustomerOrder>> {
  final _random = Random();

  @override
  List<CustomerOrder> build() => const [];

  /// Generate a new customer order from a random dish on the menu.
  CustomerOrder? spawnCustomer(List<Dish> menu) {
    if (menu.isEmpty) return null;
    final dish = menu[_random.nextInt(menu.length)];
    final patience = 40.0 + _random.nextInt(41); // 40-80 seconds
    final order = CustomerOrder(
      dish: dish,
      patienceSeconds: patience,
    );
    state = [...state, order];
    return order;
  }

  void markServed(CustomerOrder order) {
    order.status = OrderStatus.served;
    state = List.of(state);
  }

  void markExpired(CustomerOrder order) {
    order.status = OrderStatus.expired;
    state = List.of(state);
  }

  void markCooking(CustomerOrder order) {
    order.status = OrderStatus.cooking;
    state = List.of(state);
  }

  void clear() {
    state = const [];
  }

  int get servedCount =>
      state.where((o) => o.status == OrderStatus.served).length;

  int get missedCount =>
      state.where((o) => o.status == OrderStatus.expired).length;

  List<CustomerOrder> get waitingOrders =>
      state.where((o) => o.status == OrderStatus.waiting).toList();
}

final customerQueueProvider =
    NotifierProvider<CustomerQueueNotifier, List<CustomerOrder>>(
  CustomerQueueNotifier.new,
);
