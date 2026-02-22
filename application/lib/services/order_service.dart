// services/order_service.dart
import 'dart:convert';
import 'package:application/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_item.dart';

class OrderService {
  Future<String?> _resolveToken(String? authToken) async {
    if (authToken != null && authToken.isNotEmpty) return authToken;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Order> createOrder(Order order, {String? authToken}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final resolvedToken = await _resolveToken(authToken);
    if (resolvedToken != null && resolvedToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $resolvedToken';
    }

    final response = await ApiClient.post(
      '/api/orders',
      headers: headers,
      body: json.encode(order.toJson()),
    );

    if (response.statusCode == 201) {
      return Order.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create order: ${response.body}');
    }
  }

  Future<List<Order>> getUserOrders(String userId, {String? authToken}) async {
    final headers = <String, String>{};
    final resolvedToken = await _resolveToken(authToken);
    if (resolvedToken != null && resolvedToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $resolvedToken';
    }
    final response = await ApiClient.get(
      '/api/orders/user/$userId',
      headers: headers.isEmpty ? null : headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Order.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load orders');
    }
  }

  // Add method to get florist orders
  Future<List<Order>> getFloristOrders(String floristId, {String? authToken}) async {
    final headers = <String, String>{};
    final resolvedToken = await _resolveToken(authToken);
    if (resolvedToken != null && resolvedToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $resolvedToken';
    }
    final response = await ApiClient.get(
      '/api/orders/florist/$floristId',
      headers: headers.isEmpty ? null : headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Order.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load florist orders');
    }
  }
}
