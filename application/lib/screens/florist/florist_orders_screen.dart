import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FloristOrdersScreen extends StatefulWidget {
  final String authToken;
  final String userId;

  const FloristOrdersScreen({
    super.key,
    required this.authToken,
    required this.userId,
  });

  @override
  State<FloristOrdersScreen> createState() => _FloristOrdersScreenState();
}

class _FloristOrdersScreenState extends State<FloristOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _selectedFilter = 'all';
  String? _floristId;

  // Statistics data
  Map<String, dynamic> _statistics = {
    'totalOrders': 0,
    'totalRevenue': 0.0,
    'averageOrderValue': 0.0,
    'pendingOrders': 0,
    'confirmedOrders': 0,
    'preparingOrders': 0,
    'deliveringOrders': 0,
    'deliveredOrders': 0,
    'cancelledOrders': 0,
    'mostRecentOrder': 'No orders',
    'todayRevenue': 0.0,
    'thisWeekRevenue': 0.0,
    'thisMonthRevenue': 0.0,
    'topCustomer': 'No customers',
    'topCustomerOrders': 0,
  };

  // Debug info
  List<String> _debugInfo = [];

  @override
  void initState() {
    super.initState();
    _debugInfo.add('Initializing FloristOrdersScreen');
    _debugInfo.add('User ID: ${widget.userId}');
    _debugInfo.add('Token exists: ${widget.authToken.isNotEmpty}');
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _debugInfo.add('Starting to load orders...');
    });

    try {
      // First, try to get ALL orders to see what we have
      _debugInfo.add('Fetching all orders from /api/orders');
      final allOrdersResponse = await http.get(
        Uri.parse('http://localhost:4040/api/orders'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      _debugInfo.add('Response status: ${allOrdersResponse.statusCode}');

      if (allOrdersResponse.statusCode == 200) {
        final List<dynamic> allOrders = json.decode(allOrdersResponse.body);
        _debugInfo.add('Total orders in system: ${allOrders.length}');

        // Log all florist IDs found in orders
        final floristIds = <String>{};
        for (var order in allOrders) {
          if (order['floristId'] != null) {
            floristIds.add(order['floristId'].toString());
          }
        }
        _debugInfo.add('Florist IDs found in orders: ${floristIds.join(', ')}');

        // Try different approaches to get florist orders
        List<dynamic> floristOrders = [];

        // Approach 1: Try the /florist endpoint if we know the florist ID
        final possibleFloristIds = [
          widget.userId, // User ID might be the florist ID
          '697dd0fe768e6f85b18de66a', // Example from your data
          'Maner_3', // Another example
          'Maner_1', // Another example
        ];

        for (var testFloristId in possibleFloristIds) {
          _debugInfo.add(
            'Trying to fetch orders for florist ID: $testFloristId',
          );
          try {
            final floristResponse = await http.get(
              Uri.parse(
                'http://localhost:4040/api/orders/florist/$testFloristId',
              ),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer ${widget.authToken}',
              },
            );

            if (floristResponse.statusCode == 200) {
              final orders = json.decode(floristResponse.body);
              if (orders is List && orders.isNotEmpty) {
                _debugInfo.add(
                  'Found ${orders.length} orders for florist ID: $testFloristId',
                );
                floristOrders = orders;
                _floristId = testFloristId;
                break;
              }
            }
          } catch (e) {
            _debugInfo.add('Error fetching for $testFloristId: $e');
          }
        }

        // Approach 2: If no specific florist orders found, filter from all orders
        if (floristOrders.isEmpty) {
          _debugInfo.add(
            'No florist-specific orders found, filtering from all orders',
          );

          // Show ALL orders for debugging
          _debugInfo.add('Showing all orders for debugging:');
          for (var order in allOrders) {
            _debugInfo.add(
              'Order: ${order['_id']}, FloristID: ${order['floristId']}, Status: ${order['status']}',
            );
          }

          // Try to get orders where floristId is not null
          floristOrders = allOrders
              .where((order) => order['floristId'] != null)
              .toList();
          _debugInfo.add('Orders with floristId: ${floristOrders.length}');
        }

        // Process the orders for display
        final List<Map<String, dynamic>> processedOrders = [];

        for (var order in floristOrders) {
          processedOrders.add(_processOrder(order));
        }

        // Calculate statistics
        _calculateStatistics(processedOrders);

        setState(() {
          _orders = processedOrders;
          _isLoading = false;
          _debugInfo.add('Successfully loaded ${_orders.length} orders');
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load orders (Status: ${allOrdersResponse.statusCode})';
          _isLoading = false;
          _debugInfo.add('Error: $_errorMessage');
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
        _debugInfo.add('Exception: $_errorMessage');
      });
    }
  }

  void _calculateStatistics(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = now.subtract(Duration(days: 7));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);

    Map<String, int> customerOrderCounts = {};
    Map<String, double> customerRevenue = {};

    double totalRevenue = 0.0;
    double todayRevenue = 0.0;
    double weekRevenue = 0.0;
    double monthRevenue = 0.0;

    Map<String, int> statusCounts = {
      'pending': 0,
      'confirmed': 0,
      'preparing': 0,
      'delivering': 0,
      'delivered': 0,
      'cancelled': 0,
    };

    // Find most recent order
    String mostRecentOrder = 'No orders';
    DateTime? mostRecentDate;

    for (var order in orders) {
      // Calculate revenue
      double orderAmount = order['totalAmount'] ?? 0.0;
      totalRevenue += orderAmount;

      // Get order date
      try {
        final orderDate = DateTime.parse(
          order['rawOrder']['createdAt'] ?? order['createdAt'],
        );

        // Check if today
        if (orderDate.isAfter(today) || orderDate.isAtSameMomentAs(today)) {
          todayRevenue += orderAmount;
        }

        // Check if this week
        if (orderDate.isAfter(weekAgo)) {
          weekRevenue += orderAmount;
        }

        // Check if this month
        if (orderDate.isAfter(monthAgo)) {
          monthRevenue += orderAmount;
        }

        // Update most recent order
        if (mostRecentDate == null || orderDate.isAfter(mostRecentDate)) {
          mostRecentDate = orderDate;
          mostRecentOrder = order['orderNumber'];
        }
      } catch (e) {
        // Skip date parsing errors
      }

      // Count status
      String status = order['status']?.toString().toLowerCase() ?? 'pending';
      if (statusCounts.containsKey(status)) {
        statusCounts[status] = statusCounts[status]! + 1;
      }

      // Track customer orders
      String customerName = order['customerName'] ?? 'Unknown';
      customerOrderCounts[customerName] =
          (customerOrderCounts[customerName] ?? 0) + 1;
      customerRevenue[customerName] =
          (customerRevenue[customerName] ?? 0.0) + orderAmount;
    }

    // Find top customer
    String topCustomer = 'No customers';
    int topCustomerOrders = 0;
    customerOrderCounts.forEach((customer, count) {
      if (count > topCustomerOrders) {
        topCustomerOrders = count;
        topCustomer = customer;
      }
    });

    // Calculate average order value
    double averageOrderValue = orders.isNotEmpty
        ? totalRevenue / orders.length
        : 0.0;

    setState(() {
      _statistics = {
        'totalOrders': orders.length,
        'totalRevenue': totalRevenue,
        'averageOrderValue': averageOrderValue,
        'pendingOrders': statusCounts['pending'] ?? 0,
        'confirmedOrders': statusCounts['confirmed'] ?? 0,
        'preparingOrders': statusCounts['preparing'] ?? 0,
        'deliveringOrders': statusCounts['delivering'] ?? 0,
        'deliveredOrders': statusCounts['delivered'] ?? 0,
        'cancelledOrders': statusCounts['cancelled'] ?? 0,
        'mostRecentOrder': mostRecentOrder,
        'todayRevenue': todayRevenue,
        'thisWeekRevenue': weekRevenue,
        'thisMonthRevenue': monthRevenue,
        'topCustomer': topCustomer,
        'topCustomerOrders': topCustomerOrders,
      };
    });
  }

  Map<String, dynamic> _processOrder(Map<String, dynamic> order) {
    // Get customer info
    Map<String, dynamic> customer = {};
    if (order['userId'] is Map) {
      customer = order['userId'];
    } else if (order['userId'] is String) {
      customer = {'_id': order['userId']};
    }

    // Get deliver info
    Map<String, dynamic> deliver = {};
    if (order['deliverId'] is Map) {
      deliver = order['deliverId'];
    } else if (order['deliverId'] is String) {
      deliver = {'_id': order['deliverId']};
    }

    // Parse items
    List<Map<String, dynamic>> items = [];
    if (order['items'] is List) {
      items = List<Map<String, dynamic>>.from(order['items']);
    }

    // Format order number
    String orderNumber =
        order['orderNumber'] ?? '#${order['_id']?.toString().substring(0, 8)}';

    // Format date
    String formattedDate = '';
    if (order['createdAt'] != null) {
      try {
        final date = DateTime.parse(order['createdAt']).toLocal();
        formattedDate =
            '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        formattedDate = order['createdAt'].toString();
      }
    }

    return {
      'id': order['_id'] ?? '',
      'orderNumber': orderNumber,
      'customerName': customer['name'] ?? order['customerName'] ?? 'Customer',
      'customerPhone':
          customer['phone'] ?? order['customerPhone'] ?? 'No phone',
      'customerEmail':
          customer['email'] ?? order['customerEmail'] ?? 'No email',
      'customerCity': customer['city'] ?? order['city'] ?? '',
      'totalAmount': order['totalPrice'] is num
          ? (order['totalPrice'] as num).toDouble()
          : 0.0,
      'status': order['status'] ?? 'pending',
      'createdAt': formattedDate,
      'deliveryAddress': order['deliveryAddress'] ?? 'No address',
      'deliverName': deliver['name'] ?? 'Not assigned',
      'deliverPhone': deliver['phone'] ?? '',
      'items': items,
      'rawOrder': order,
      'floristId': order['floristId']?.toString() ?? '',
    };
  }

  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('http://localhost:4040/api/orders/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 200) {
        await _loadOrders(); // Refresh orders
        _showSnackBar('Order status updated to $status');
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar('Error: ${errorData['error'] ?? 'Update failed'}');
      }
    } catch (e) {
      _showSnackBar('Error updating status: $e');
    }
  }

  Widget _buildStatisticsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shop Statistics',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _loadOrders,
                tooltip: 'Refresh Statistics',
              ),
            ],
          ),
          SizedBox(height: 16),

          // Revenue Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Total Revenue',
                  value: '₸ ${_statistics['totalRevenue'].toStringAsFixed(0)}',
                  icon: Icons.attach_money,
                  color: Colors.pink,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Avg Order Value',
                  value:
                      '₸ ${_statistics['averageOrderValue'].toStringAsFixed(0)}',
                  icon: Icons.bar_chart,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Today Revenue',
                  value: '₸ ${_statistics['todayRevenue'].toStringAsFixed(0)}',
                  icon: Icons.today,
                  color: Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'This Month',
                  value:
                      '₸ ${_statistics['thisMonthRevenue'].toStringAsFixed(0)}',
                  icon: Icons.calendar_month,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),

          // Order Statistics
          Text(
            'Order Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          _buildStatCard(
            title: 'Total Orders',
            value: _statistics['totalOrders'].toString(),
            icon: Icons.shopping_bag,
            color: Colors.blue,
            subtitle: 'Most recent: ${_statistics['mostRecentOrder']}',
          ),
          SizedBox(height: 12),

          // Order Status Breakdown
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Status Breakdown',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Column(
                    children: [
                      _buildStatusRow(
                        'Pending',
                        _statistics['pendingOrders'],
                        Colors.orange,
                      ),
                      _buildStatusRow(
                        'Confirmed',
                        _statistics['confirmedOrders'],
                        Colors.blue,
                      ),
                      _buildStatusRow(
                        'Preparing',
                        _statistics['preparingOrders'],
                        Colors.purple,
                      ),
                      _buildStatusRow(
                        'Delivering',
                        _statistics['deliveringOrders'],
                        Colors.teal,
                      ),
                      _buildStatusRow(
                        'Delivered',
                        _statistics['deliveredOrders'],
                        Colors.green,
                      ),
                      _buildStatusRow(
                        'Cancelled',
                        _statistics['cancelledOrders'],
                        Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Customer Insights
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Insights',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  ListTile(
                    leading: Icon(Icons.person, color: Colors.amber),
                    title: Text('Top Customer'),
                    subtitle: Text(_statistics['topCustomer']),
                    trailing: Chip(
                      label: Text('${_statistics['topCustomerOrders']} orders'),
                      backgroundColor: Colors.amber.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _loadOrders,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Refresh Statistics'),
                ),
                SizedBox(height: 8),
                Text(
                  'Last updated: ${DateTime.now().toString().split(' ')[0]}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String status, int count, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 8),
          Expanded(child: Text(status, style: TextStyle(fontSize: 14))),
          Text(
            '$count',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    final statuses = [
      'all',
      'pending',
      'confirmed',
      'preparing',
      'delivering',
      'delivered',
      'cancelled',
    ];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          final status = statuses[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(status.toUpperCase()),
              selected: _selectedFilter == status,
              selectedColor: _getStatusColor(status),
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = selected ? status : 'all';
                });
              },
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredOrders() {
    if (_selectedFilter == 'all') {
      return _orders;
    }
    return _orders
        .where((order) => order['status'].toLowerCase() == _selectedFilter)
        .toList();
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

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'delivering':
        return 'Delivering';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.pink,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 8, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              order['orderNumber'],
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                order['status'],
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getStatusColor(
                                  order['status'],
                                ).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _getStatusText(order['status']),
                              style: TextStyle(
                                fontSize: 14,
                                color: _getStatusColor(order['status']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ordered on: ${order['createdAt']}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),

                      if (order['floristId'].isNotEmpty)
                        Text(
                          'Shop ID: ${order['floristId']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),

                      Divider(height: 24),

                      // Customer Information
                      Text(
                        'Customer Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildDetailRow('Name', order['customerName']),
                      _buildDetailRow('Phone', order['customerPhone']),
                      _buildDetailRow('Email', order['customerEmail']),
                      _buildDetailRow('City', order['customerCity']),

                      Divider(height: 24),

                      // Delivery Information
                      Text(
                        'Delivery Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildDetailRow('Address', order['deliveryAddress']),
                      _buildDetailRow('Delivery Person', order['deliverName']),
                      if (order['deliverPhone']?.isNotEmpty == true)
                        _buildDetailRow(
                          'Delivery Phone',
                          order['deliverPhone'],
                        ),

                      Divider(height: 24),

                      // Order Items
                      Text(
                        'Order Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      if (order['items'].isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No items in this order',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      else
                        ...order['items'].map<Widget>((item) {
                          return Container(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item['quantity']}x ${item['productName'] ?? 'Item'}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (item['flowerId'] != null)
                                        Text(
                                          'Flower ID: ${item['flowerId']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₸ ${(item['price'] is num ? item['price'].toDouble() : 0.0).toStringAsFixed(0)} each',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    Text(
                                      '₸ ${((item['price'] is num ? item['price'].toDouble() : 0.0) * (item['quantity'] is num ? item['quantity'].toInt() : 1)).toStringAsFixed(0)} total',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.pink,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),

                      Divider(height: 24),

                      // Total Amount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₸ ${order['totalAmount'].toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.pink,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Status Update Buttons
                      if (order['status'] == 'pending')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _updateOrderStatus(order['id'], 'confirmed');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text('Confirm Order'),
                          ),
                        ),

                      if (order['status'] == 'confirmed')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _updateOrderStatus(order['id'], 'preparing');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text('Start Preparing'),
                          ),
                        ),

                      if (order['status'] == 'preparing')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _updateOrderStatus(order['id'], 'delivering');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text('Ready for Delivery'),
                          ),
                        ),

                      if (order['status'] != 'cancelled' &&
                          order['status'] != 'delivered')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _updateOrderStatus(order['id'], 'cancelled');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text('Cancel Order'),
                          ),
                        ),

                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not provided',
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    return GestureDetector(
      onTap: () => _showOrderDetails(order),
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order['orderNumber'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(
                          order['status'],
                        ).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _getStatusText(order['status']),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(order['status']),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Customer: ${order['customerName']}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 4),
              Text(
                'Phone: ${order['customerPhone']}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              SizedBox(height: 4),
              Text(
                'Address: ${order['deliveryAddress']}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₸ ${order['totalAmount'].toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.pink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${order['items'].length} item${order['items'].length != 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        order['createdAt'].split(' ')[0],
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Florist Dashboard'),
          automaticallyImplyLeading: false,
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.shopping_bag)), // Orders tab - icon only
              Tab(icon: Icon(Icons.analytics)), // Statistics tab - icon only
            ],
            labelColor: Colors.pink, // Active tab color
            unselectedLabelColor: Colors.grey, // Inactive tab color
            indicatorColor: Colors.pink, // Indicator color
          ),
        ),
        body: TabBarView(
          children: [
            // Orders Tab
            Column(
              children: [
                if (_orders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildStatusFilter(),
                  ),
                Expanded(
                  child: _isLoading && _orders.isEmpty
                      ? Center(child: CircularProgressIndicator())
                      : _errorMessage.isNotEmpty && _orders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 60,
                                color: Colors.red,
                              ),
                              SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadOrders,
                                child: Text('Retry'),
                              ),
                              SizedBox(height: 8),
                            ],
                          ),
                        )
                      : _orders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 60,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No shop orders yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _floristId != null
                                          ? 'Your shop ID: $_floristId'
                                          : 'Shop ID not found',
                                      style: TextStyle(color: Colors.grey[500]),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Orders placed for your shop will appear here',
                                      style: TextStyle(color: Colors.grey[500]),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadOrders,
                                child: Text('Refresh'),
                              ),
                              SizedBox(height: 8),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadOrders,
                          child: _getFilteredOrders().isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.filter_alt,
                                        size: 60,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'No orders with status "$_selectedFilter"',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _selectedFilter = 'all';
                                          });
                                        },
                                        child: Text('Show all orders'),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _getFilteredOrders().length,
                                  itemBuilder: (context, index) {
                                    return _buildOrderCard(
                                      _getFilteredOrders()[index],
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
            // Statistics Tab
            _buildStatisticsTab(),
          ],
        ),
      ),
    );
  }
}
