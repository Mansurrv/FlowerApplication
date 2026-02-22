import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/basket_item.dart';

class BasketProvider with ChangeNotifier {
  final List<BasketItem> _items = [];
  double _totalPrice = 0.0;
  String? _currentUserId;

  String? get currentUserId => _currentUserId;

  List<BasketItem> get items => _items;
  double get totalPrice => _totalPrice;
  int get itemCount => _items.length;

  Future<void> loadForUser(String? userId) async {
    final normalized = userId?.trim() ?? '';
    if (normalized.isEmpty) {
      _currentUserId = null;
      _items.clear();
      _totalPrice = 0.0;
      notifyListeners();
      return;
    }

    if (_currentUserId == normalized) {
      return;
    }

    _currentUserId = normalized;
    _items.clear();
    _totalPrice = 0.0;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUserId != normalized) {
        return;
      }
      final raw = prefs.getString(_storageKey(normalized));
      if (raw == null || raw.isEmpty) {
        notifyListeners();
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        if (_currentUserId != normalized) {
          return;
        }
        _items.clear();
        for (final entry in decoded) {
          if (entry is Map<String, dynamic>) {
            _items.add(BasketItem.fromJson(entry));
          } else if (entry is Map) {
            _items.add(BasketItem.fromJson(Map<String, dynamic>.from(entry)));
          }
        }
        _calculateTotal();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading basket: $e');
      }
    } finally {
      notifyListeners();
    }
  }

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
    _saveForCurrentUser();
  }

  void removeItem(String flowerId) {
    _items.removeWhere((item) => item.flowerId == flowerId);
    _calculateTotal();
    notifyListeners();
    _saveForCurrentUser();
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
      _saveForCurrentUser();
    }
  }

  void clearBasket() {
    _items.clear();
    _totalPrice = 0.0;
    notifyListeners();
    _saveForCurrentUser();
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

  String _storageKey(String userId) => 'basket_$userId';

  Future<void> _saveForCurrentUser() async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(_items.map((item) => item.toJson()).toList());
      await prefs.setString(_storageKey(userId), payload);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving basket: $e');
      }
    }
  }
}
