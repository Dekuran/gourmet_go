import 'package:flame/components.dart';

import '../../../models/customer_order.dart';
import '../chef/chef_entity.dart';
import '../customer/customer_entity.dart';

/// Routes tapped orders from customers to the chef's queue.
class OrderDispatcher extends Component {
  ChefEntity? chef;

  /// Assign a customer's order to the chef.
  ///
  /// Silently ignores the tap if no chef is registered or if the
  /// customer's order is already assigned.
  void assign(CustomerOrder order, CustomerEntity customer) {
    if (chef == null) return;
    if (order.status != OrderStatus.waiting) return;
    chef!.enqueue(order);
    customer.markAssigned();
  }
}
