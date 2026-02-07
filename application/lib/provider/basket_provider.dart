import 'package:flutter/foundation.dart';
import '../models/basket_item.dart';

class BasketProvider with ChangeNotifier {
  final List<BasketItem> _items = [];
  double _totalPrice = 0.0;

  List<BasketItem> get items => _items;
  double get totalPrice => _totalPrice;
  int get itemCount => _items.length;

  void addItem(BasketItem item) {
    final existingIndex = _items.indexWhere((i) => i.flowerId == item.flowerId);

    if (existingIndex >= 0) {
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + item.quantity,
      );
    } else {
      _items.add(item);
    }
    _calculateTotal();
    notifyListeners();
  }

  void removeItem(String flowerId) {
    _items.removeWhere((item) => item.flowerId == flowerId);
    _calculateTotal();
    notifyListeners();
  }

  void updateQuantity(String flowerId, int quantity) {
    final index = _items.indexWhere((item) => item.flowerId == flowerId);
    if (index >= 0) {
      if (quantity > 0) {
        _items[index] = _items[index].copyWith(quantity: quantity);
      } else {
        _items.removeAt(index);
      }
      _calculateTotal();
      notifyListeners();
    }
  }

  void clearBasket() {
    _items.clear();
    _totalPrice = 0.0;
    notifyListeners();
  }

  void _calculateTotal() {
    _totalPrice = _items.fold(0.0, (sum, item) => sum + item.total);
  }

  bool isInBasket(String flowerId) {
    return _items.any((item) => item.flowerId == flowerId);
  }

  int getItemQuantity(String flowerId) {
    final item = _items.firstWhere(
      (item) => item.flowerId == flowerId,
      orElse: () => BasketItem(
        id: '',
        flowerId: '',
        name: '',
        price: 0.0,
        quantity: 0,
        imageUrl: '',
        floristId: '',
      ),
    );
    return item.quantity;
  }
}
