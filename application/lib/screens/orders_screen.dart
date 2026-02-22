// screens/orders_screen.dart
import 'package:application/models/order_item.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:application/services/api_client.dart';
import '../services/auth_service.dart';
import '../models/order_item.dart';

class OrdersScreen extends StatefulWidget {
  final AuthService authService;

  const OrdersScreen({super.key, required this.authService});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Map<String, String> _buildAuthHeaders() {
    final headers = <String, String>{'Accept': 'application/json'};
    final token = widget.authService.authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<void> _loadOrders() async {
    if (!widget.authService.isLoggedIn) {
      setState(() {
        _error = 'Please login to view your orders';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final userId = widget.authService.userId;
      final response = await ApiClient.get(
        '/api/orders/user/$userId',
        headers: _buildAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _orders = data.map((json) => Order.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load orders';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  bool _canCancelOrder(Order order) {
    final status = order.status.toLowerCase();
    return status == 'pending' || status == 'confirmed' || status == 'preparing';
  }

  Future<void> _cancelOrder(Order order) async {
    final orderId = order.id;
    if (orderId == null || orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to cancel: missing order ID')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Order'),
        content: Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final cancelResponse = await ApiClient.put(
        '/api/orders/$orderId/status',
        headers: {
          ..._buildAuthHeaders(),
          'Content-Type': 'application/json',
        },
        body: json.encode({'status': 'cancelled'}),
      );

      if (cancelResponse.statusCode != 200) {
        String message = 'Failed to cancel order';
        try {
          final errorData = json.decode(cancelResponse.body);
          message = errorData['error'] ?? message;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }

      final deleteResponse = await ApiClient.delete(
        '/api/orders/$orderId',
        headers: _buildAuthHeaders(),
      );

      if (deleteResponse.statusCode == 200) {
        setState(() {
          _orders.removeWhere((o) => o.id == orderId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order cancelled and removed'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        String message = 'Cancelled but failed to remove order';
        try {
          final errorData = json.decode(deleteResponse.body);
          message = errorData['error'] ?? message;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: ${e.toString()}')),
      );
    }
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order #${order.orderNumber ?? order.id?.substring(0, 8)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                SizedBox(width: 6),
                Text(
                  'Placed on: ${order.createdAt?.toLocal().toString().split(' ')[0]}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Total: ₸ ${order.totalPrice.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Delivery Address: ${order.deliveryAddress}',
              style: TextStyle(color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 12),
            if (order.items.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  ...order.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${item.quantity}x Item (₸ ${item.price.toStringAsFixed(0)} each)',
                        style: TextStyle(fontSize: 12),
                      ),
                    );
                  }),
                ],
              ),
            if (_canCancelOrder(order)) ...[
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelOrder(order),
                  icon: Icon(Icons.cancel, color: Colors.red),
                  label: Text(
                    'Cancel Order',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'delivering':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Orders'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadOrders),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    _error,
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadOrders, child: Text('Retry')),
                ],
              ),
            )
          : _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No orders yet', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  Text(
                    'Your orders will appear here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView.builder(
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(_orders[index]);
                },
              ),
            ),
    );
  }
}
