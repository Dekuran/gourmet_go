import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Till balance for the restaurant.
class CashNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void earn(int amount) {
    state = state + amount;
  }

  bool spend(int amount) {
    if (state < amount) return false;
    state = state - amount;
    return true;
  }

  void set(int amount) {
    state = amount;
  }
}

final cashProvider = NotifierProvider<CashNotifier, int>(
  CashNotifier.new,
);
