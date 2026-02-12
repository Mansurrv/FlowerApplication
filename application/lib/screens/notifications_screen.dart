import 'dart:convert';

import 'package:application/services/api_client.dart';
import 'package:application/services/auth_service.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  final AuthService authService;

  const NotificationsScreen({super.key, required this.authService});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final userId = widget.authService.userId ?? '';
    if (userId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Please log in to view notifications.';
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiClient.get(
        '/api/notifications/',
        headers: {'Accept': 'application/json'},
        queryParameters: {'to_user': userId},
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> data = decoded is List
            ? decoded
            : decoded is Map<String, dynamic> && decoded['data'] is List
            ? decoded['data'] as List
            : [];
        if (!mounted) return;
        setState(() {
          _notifications = data.whereType<Map<String, dynamic>>().toList(
            growable: true,
          );
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Failed to load notifications (Status: ${response.statusCode})';
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

  String _formatTimestamp(dynamic value) {
    if (value == null) return '';
    try {
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          value * 1000,
        ).toLocal().toString();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            parsed * 1000,
          ).toLocal().toString();
        }
      }
    } catch (_) {}
    return '';
  }

  String _extractFromUser(Map<String, dynamic> notification) {
    final fromValue = notification['from_user'];
    if (fromValue is Map) {
      final email = fromValue['email']?.toString() ?? '';
      return email;
    }
    final raw = fromValue?.toString() ?? '';
    return raw.contains('@') ? raw : '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(_errorMessage)),
                ],
              )
            : _notifications.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No notifications yet')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final message = notification['message']?.toString() ?? '';
                  final fromUser = _extractFromUser(notification);
                  final createdAt = _formatTimestamp(
                    notification['created_at'],
                  );

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.isEmpty
                              ? 'New wishlist notification'
                              : message,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (fromUser.isNotEmpty)
                          Text(
                            'From: $fromUser',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (createdAt.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              createdAt,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              final id =
                                  notification['_id']?.toString() ??
                                  notification['id']?.toString() ??
                                  '';
                              if (id.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Missing notification id.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              try {
                                final response = await ApiClient.delete(
                                  '/api/notifications/$id',
                                  headers: {'Accept': 'application/json'},
                                );
                                if (!mounted) return;
                                if (response.statusCode == 200) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Marked as ready.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  if (!mounted) return;
                                  setState(() {
                                    _notifications.removeAt(index);
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to delete (Status: ${response.statusCode})',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Network error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: const Text('Ready'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
