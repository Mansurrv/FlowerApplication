// services/order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order_item.dart';

class OrderService {
  static const String baseUrl = 'http://localhost:4040/api/orders';

  Future<Order> createOrder(Order order) async {
    final response = await http.post(
      Uri.parse(baseUrl),
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
    final response = await http.get(Uri.parse('$baseUrl/user/$userId'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Order.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load orders');
    }
  }

  // Add method to get florist orders
  Future<List<Order>> getFloristOrders(String floristId) async {
    final response = await http.get(Uri.parse('$baseUrl/florist/$floristId'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Order.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load florist orders');
    }
  }
}
