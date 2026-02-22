import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:application/services/api_client.dart';

class AdminUserManagementScreen extends StatefulWidget {
  final String authToken;
  final String role;
  final String title;

  const AdminUserManagementScreen({
    super.key,
    required this.authToken,
    required this.role,
    required this.title,
  });

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState
    extends State<AdminUserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _statusFilter = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiClient.get(
        '/api/admin/users',
        queryParameters: {
          'role': widget.role,
        },
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> rawList = [];
        if (data is List) {
          rawList = data;
        } else if (data is Map && data['users'] is List) {
          rawList = data['users'];
        }

        final normalized = rawList
            .map<Map<String, dynamic>>((user) => _normalizeUser(user))
            .toList();
        final roleFiltered = normalized.where((user) {
          final role = (user['role'] ?? '').toString();
          return role == widget.role;
        }).toList();

        if (!mounted) return;
        setState(() {
          _users = roleFiltered;
          _isLoading = false;
        });
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Not authorized to access admin data';
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Failed to load users (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _normalizeUser(dynamic user) {
    if (user is Map) {
      return {
        'id': (user['_id'] ?? user['id'] ?? '').toString(),
        'name': (user['name'] ?? 'No name').toString(),
        'email': (user['email'] ?? '').toString(),
        'city': (user['city'] ?? '').toString(),
        'phone': (user['phone'] ?? '').toString(),
        'shopName': (user['shopName'] ?? '').toString(),
        'status': (user['status'] ?? 'active').toString(),
        'role': (user['role'] ?? '').toString(),
        'rating': user['rating'] ?? 0,
        'totalReviews': user['totalReviews'] ?? 0,
      };
    }
    return {
      'id': '',
      'name': 'No name',
      'email': '',
      'city': '',
      'phone': '',
      'shopName': '',
      'status': 'active',
      'role': widget.role,
      'rating': 0,
      'totalReviews': 0,
    };
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final statusFilter = _statusFilter.toLowerCase();
    final query = _searchQuery.trim().toLowerCase();

    return _users.where((user) {
      final status = (user['status'] ?? 'active').toString().toLowerCase();
      final matchesStatus =
          statusFilter == 'all' || status == statusFilter;

      final combined =
          '${user['name']} ${user['email']} ${user['phone']} ${user['shopName']} ${user['city']}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || combined.contains(query);

      return matchesStatus && matchesQuery;
    }).toList();
  }

  Future<void> _updateStatus(String userId, String status) async {
    try {
      final response = await ApiClient.patch(
        '/api/admin/users/$userId',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _users = _users.map((user) {
            if (user['id'] == userId) {
              return {...user, 'status': status};
            }
            return user;
          }).toList();
        });
        _showSnack('Status updated');
      } else {
        _showSnack('Failed to update status');
      }
    } catch (e) {
      _showSnack('Network error: ${e.toString()}');
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      final response = await ApiClient.delete(
        '/api/admin/users/$userId',
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _users = _users.where((user) => user['id'] != userId).toList();
        });
        _showSnack('User deleted');
      } else {
        _showSnack('Failed to delete user');
      }
    } catch (e) {
      _showSnack('Network error: ${e.toString()}');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  IconData _roleIcon() {
    switch (widget.role) {
      case 'florist':
        return Icons.local_florist;
      case 'deliver':
        return Icons.local_shipping;
      default:
        return Icons.person;
    }
  }

  Color _roleColor() {
    switch (widget.role) {
      case 'florist':
        return Colors.pink.shade200;
      case 'deliver':
        return Colors.blue.shade200;
      default:
        return Colors.grey.shade300;
    }
  }

  String _infoLine(Map<String, dynamic> user) {
    final parts = <String>[];
    final phone = (user['phone'] ?? '').toString();
    final city = (user['city'] ?? '').toString();
    final shopName = (user['shopName'] ?? '').toString();

    if (phone.isNotEmpty) parts.add(phone);
    if (city.isNotEmpty) parts.add(city);

    if (widget.role == 'florist' && shopName.isNotEmpty) {
      parts.add(shopName);
    }

    if (widget.role == 'florist' && user['rating'] != null) {
      final rating = user['rating'].toString();
      parts.add('Rating $rating');
    }

    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _filteredUsers;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(filteredUsers.length),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? _buildError()
                      : filteredUsers.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _fetchUsers,
                              child: ListView.builder(
                                itemCount: filteredUsers.length,
                                itemBuilder: (context, index) {
                                  return _buildUserCard(filteredUsers[index]);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.title} ($count)',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchUsers,
              ),
              DropdownButton<String>(
                value: _statusFilter,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _statusFilter = value;
                  });
                },
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(value: 'Active', child: Text('Active')),
                  DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, email, phone...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final status = (user['status'] ?? 'active').toString();
    final isActive = status == 'active';
    final infoLine = _infoLine(user);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        isThreeLine: infoLine.isNotEmpty,
        leading: CircleAvatar(
          backgroundColor: _roleColor(),
          child: Icon(_roleIcon(), color: Colors.white),
        ),
        title: Text(user['name'] ?? 'No name'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? ''),
            if (infoLine.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  infoLine,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.shade100 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'toggle') {
                  final newStatus = isActive ? 'inactive' : 'active';
                  _updateStatus(user['id'], newStatus);
                }
                if (value == 'delete') {
                  _confirmDelete(user);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(isActive ? 'Deactivate' : 'Activate'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    final name = (user['name'] ?? 'this user').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete user'),
          content: Text('Are you sure you want to delete $name?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteUser(user['id']);
    }
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_roleIcon(), size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No ${widget.title.toLowerCase()} found',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
