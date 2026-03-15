import 'dish.dart';

/// A mechanical customer order: a dish + patience timer.
///
/// No customer name, personality, or type — purely mechanical.
class CustomerOrder {
  final Dish dish;
  final double patienceSeconds;
  final DateTime arrivalTime;
  OrderStatus status;

  CustomerOrder({
    required this.dish,
    required this.patienceSeconds,
    DateTime? arrivalTime,
    this.status = OrderStatus.waiting,
  }) : arrivalTime = arrivalTime ?? DateTime.now();
}

/// Status of a mechanical customer order.
enum OrderStatus {
  waiting,
  cooking,
  served,
  expired,
}
