import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:application/services/api_client.dart';

class DeliverOrdersScreen extends StatefulWidget {
  final String authToken;
  final String userId;

  const DeliverOrdersScreen({
    super.key,
    required this.authToken,
    required this.userId,
  });

  @override
  State<DeliverOrdersScreen> createState() => _DeliverOrdersScreenState();
}

class _DeliverOrdersScreenState extends State<DeliverOrdersScreen> {
  List<Map<String, dynamic>> _available = [];
  List<Map<String, dynamic>> _myOrders = [];
  bool _isLoading = false;
  String _error = '';
  String _statusFilter = 'All';

  Map<String, String> _authHeaders({bool includeJson = false}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (includeJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (widget.authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${widget.authToken}';
    }
    return headers;
  }

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final availableResponse = await ApiClient.get(
        '/api/orders/available',
        headers: _authHeaders(),
      );
      final myResponse = await ApiClient.get(
        '/api/orders/deliver/${widget.userId}',
        headers: _authHeaders(),
      );

      if (availableResponse.statusCode == 200 &&
          myResponse.statusCode == 200) {
        final availableData = json.decode(availableResponse.body);
        final myData = json.decode(myResponse.body);

        if (!mounted) return;
        setState(() {
          _available = _normalizeOrders(availableData);
          _myOrders = _normalizeOrders(myData);
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error =
              'Failed to load orders '
              '(${availableResponse.statusCode}/${myResponse.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _normalizeOrders(dynamic data) {
    if (data is List) {
      return data.map((o) => _mapOrder(o)).toList();
    }
    return [];
  }

  Map<String, dynamic> _mapOrder(dynamic order) {
    final user = order['userId'] is Map ? order['userId'] : {};
    final florist = order['floristId'] is Map ? order['floristId'] : {};
    return {
      'id': order['_id']?.toString() ?? '',
      'orderNumber': order['orderNumber']?.toString() ?? '',
      'status': order['status']?.toString() ?? 'pending',
      'totalPrice': order['totalPrice'] is num
          ? (order['totalPrice'] as num).toDouble()
          : 0.0,
      'createdAt': order['createdAt']?.toString() ?? '',
      'deliveryAddress': order['deliveryAddress']?.toString() ?? 'No address',
      'city': order['city']?.toString() ?? '',
      'customerName': user['name']?.toString() ?? 'Customer',
      'customerPhone': user['phone']?.toString() ?? '',
      'floristName': florist['shopName']?.toString() ?? '',
    };
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.orange;
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

  Future<void> _acceptOrder(String orderId) async {
    try {
      final assignResponse = await ApiClient.put(
        '/api/orders/$orderId/assign-deliver',
        headers: _authHeaders(includeJson: true),
        body: json.encode({'deliverId': widget.userId}),
      );

      if (assignResponse.statusCode == 200) {
        await _updateStatus(orderId, 'delivering');
        await _loadOrders();
      } else {
        if (!mounted) return;
        _showSnack('Failed to accept order');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Network error: ${e.toString()}');
    }
  }

  Future<void> _updateStatus(String orderId, String status) async {
    try {
      final response = await ApiClient.put(
        '/api/orders/$orderId/status',
        headers: _authHeaders(includeJson: true),
        body: json.encode({'status': status}),
      );
      if (response.statusCode != 200) {
        if (!mounted) return;
        _showSnack('Failed to update status');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Network error: ${e.toString()}');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Delivery'),
          automaticallyImplyLeading: false,
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inbox)),
              Tab(icon: Icon(Icons.local_shipping)),
            ],
            labelColor: Colors.pink,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.pink,
          ),
        ),
        body: TabBarView(
          children: [
            _buildAvailableTab(),
            _buildMyOrdersTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return _buildError();
    }
    if (_available.isEmpty) {
      return _buildEmpty('No available orders');
    }
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        itemCount: _available.length,
        itemBuilder: (context, index) {
          final order = _available[index];
          return _buildOrderCard(
            order,
            trailing: ElevatedButton(
              onPressed: () => _acceptOrder(order['id']),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
              ),
              child: Text('Accept'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyOrdersTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return _buildError();
    }
    final statusChips = [
      'All',
      'delivering',
      'delivered',
      'cancelled',
    ];
    final filtered =
        _statusFilter == 'All'
            ? _myOrders
            : _myOrders
                .where(
                  (o) =>
                      (o['status']?.toString() ?? '')
                          .toLowerCase() ==
                      _statusFilter.toLowerCase(),
                )
                .toList();

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        children: [
          _buildStatsHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 8,
              children: statusChips.map((status) {
                final isSelected = _statusFilter == status;
                return ChoiceChip(
                  label: Text(status),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _statusFilter = status;
                    });
                  },
                );
              }).toList(),
            ),
          ),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: _buildEmpty('No deliveries for this status'),
            )
          else
            ListView.builder(
              itemCount: filtered.length,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final order = filtered[index];
                final status = order['status'];
                Widget? action;
                if (status == 'delivering') {
                  action = OutlinedButton(
                    onPressed: () async {
                      await _updateStatus(order['id'], 'delivered');
                      await _loadOrders();
                    },
                    child: Text('Mark Delivered'),
                  );
                } else if (status != 'delivered' && status != 'cancelled') {
                  action = OutlinedButton(
                    onPressed: () async {
                      await _updateStatus(order['id'], 'delivering');
                      await _loadOrders();
                    },
                    child: Text('Start Delivery'),
                  );
                }
                return _buildOrderCard(order, trailing: action);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final total = _myOrders.length;
    final delivering =
        _myOrders.where((o) => o['status'] == 'delivering').length;
    final delivered =
        _myOrders.where((o) => o['status'] == 'delivered').length;
    final cancelled =
        _myOrders.where((o) => o['status'] == 'cancelled').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard('Total', total, Colors.blue),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildStatCard('Delivering', delivering, Colors.teal),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildStatCard('Delivered', delivered, Colors.green),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildStatCard('Cancelled', cancelled, Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    Map<String, dynamic> order, {
    Widget? trailing,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #${order['orderNumber']}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(order['status']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order['status'].toString().toUpperCase(),
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('Total: ₸ ${order['totalPrice'].toStringAsFixed(0)}'),
            SizedBox(height: 6),
            Text(
              'Address: ${order['deliveryAddress']}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 6),
            Text('City: ${order['city']}'),
            SizedBox(height: 6),
            Text('Customer: ${order['customerName']}'),
            if ((order['customerPhone'] ?? '').toString().isNotEmpty)
              Text('Phone: ${order['customerPhone']}'),
            if ((order['floristName'] ?? '').toString().isNotEmpty)
              Text('Florist: ${order['floristName']}'),
            if (trailing != null) ...[
              SizedBox(height: 12),
              SizedBox(width: double.infinity, child: trailing),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 12),
          Text(_error, textAlign: TextAlign.center),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadOrders,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }
}
