// services/order_service.dart
import 'dart:convert';
import 'package:application/services/api_client.dart';
import '../models/order_item.dart';

class OrderService {
  Future<Order> createOrder(Order order) async {
    final response = await ApiClient.post(
      '/api/orders',
      headers: {'Content-Type': 'application/json'},
      body: json.encode(order.toJson()),
    );

    if (response.statusCode == 201) {
      return Order.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create order: ${response.body}');
    }
  }

  Future<List<Order>> getUserOrders(String userId) async {
    final response = await ApiClient.get('/api/orders/user/$userId');

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Order.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load orders');
    }
  }

  // Add method to get florist orders
  Future<List<Order>> getFloristOrders(String floristId) async {
    final response = await ApiClient.get('/api/orders/florist/$floristId');

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Order.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load florist orders');
    }
  }
}
