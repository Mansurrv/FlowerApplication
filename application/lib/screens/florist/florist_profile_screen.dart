import 'dart:convert';
import 'package:application/main.dart';
import 'package:flutter/material.dart';
import 'package:application/services/api_client.dart';
import 'package:provider/provider.dart';
import 'package:application/services/auth_service.dart';

class FloristProfileScreen extends StatefulWidget {
  final String authToken;
  final String userId;

  const FloristProfileScreen({
    super.key,
    required this.authToken,
    required this.userId,
  });

  @override
  State<FloristProfileScreen> createState() => _FloristProfileScreenState();
}

class _FloristProfileScreenState extends State<FloristProfileScreen> {
  Map<String, dynamic> _profile = {
    'shopName': 'My Flower Shop',
    'email': 'Loading...',
    'phone': '',
    'address': '',
    'description': '',
    'rating': 0.0,
    'totalReviews': 0,
  };
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isLoggingOut = false;

  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Try the florist-specific endpoint first
      final response = await ApiClient.get(
        '/api/florists/profile',
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _profile = {
            'shopName': data['shopName'] ?? 'My Flower Shop',
            'email': data['email'] ?? 'No email',
            'phone': data['phone'] ?? '',
            'address': data['address'] ?? '',
            'description': data['description'] ?? '',
            'rating': data['rating'] is num ? data['rating'].toDouble() : 0.0,
            'totalReviews': data['totalReviews'] ?? 0,
          };
          _isLoading = false;
        });
        _updateControllers();
      } else if (response.statusCode == 404 || response.statusCode == 403) {
        // If florist endpoint doesn't exist, fall back to user endpoint
        await _fetchUserProfile();
      }
    } catch (e) {
      // Fall back to user endpoint on any error
      await _fetchUserProfile();
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      // Fallback to regular user profile endpoint
      final response = await ApiClient.get(
        '/api/users/profile',
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _profile = {
            'shopName': data['shopName'] ?? data['name'] ?? 'My Shop',
            'email': data['email'] ?? 'No email',
            'phone': data['phone'] ?? '',
            'address': data['address'] ?? data['city'] ?? '',
            'description': data['description'] ?? '',
            'rating': 0.0,
            'totalReviews': 0,
          };
          _isLoading = false;
        });
        _updateControllers();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Could not load profile');
    }
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      // Get the AuthService from Provider
      final authService = Provider.of<AuthService>(context, listen: false);

      // Call logout on AuthService
      await authService.logout();

      // Navigate to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => AuthFlowScreen()),
        (route) => false,
      );

      _showSnackBar('Logged out successfully');
    } catch (e) {
      _showSnackBar('Error during logout: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  void _updateControllers() {
    _shopNameController.text = _profile['shopName'];
    _emailController.text = _profile['email'];
    _phoneController.text = _profile['phone'];
    _addressController.text = _profile['address'];
    _descriptionController.text = _profile['description'];
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient.put(
        '/api/florists/profile',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        body: json.encode({
          'shopName': _shopNameController.text,
          'phone': _phoneController.text,
          'address': _addressController.text,
          'description': _descriptionController.text,
        }),
      );

      if (response.statusCode == 200) {
        await _fetchProfile();
        setState(() {
          _isEditing = false;
        });
        _showSnackBar('Profile updated successfully');
      }
    } catch (e) {
      _showSnackBar('Error updating profile');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.pink),
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor() ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 20,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            // REMOVE Scaffold wrapper
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.pink.shade100,
                          child: Icon(
                            Icons.store,
                            size: 40,
                            color: Colors.pink,
                          ),
                        ),
                        SizedBox(height: 16),
                        _isEditing
                            ? TextField(
                                controller: _shopNameController,
                                decoration: InputDecoration(
                                  labelText: 'Shop Name',
                                  border: OutlineInputBorder(),
                                ),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              )
                            : Text(
                                _profile['shopName'],
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildRatingStars(_profile['rating']),
                            SizedBox(width: 8),
                            Text(
                              '(${_profile['totalReviews']} reviews)',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // Profile Details
                Text(
                  'Shop Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                _buildInfoCard(
                  icon: Icons.email,
                  title: 'Email',
                  value: _profile['email'],
                  editable: false,
                  controller: _emailController,
                ),
                _buildInfoCard(
                  icon: Icons.phone,
                  title: 'Phone',
                  value: _profile['phone'],
                  editable: _isEditing,
                  controller: _phoneController,
                ),
                _buildInfoCard(
                  icon: Icons.location_on,
                  title: 'Address',
                  value: _profile['address'],
                  editable: _isEditing,
                  controller: _addressController,
                ),
                _buildInfoCard(
                  icon: Icons.description,
                  title: 'Description',
                  value: _profile['description'],
                  editable: _isEditing,
                  controller: _descriptionController,
                  multiline: true,
                ),
                SizedBox(height: 32),

                // Action Buttons
                if (_isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _updateProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('Save Changes'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _updateControllers();
                            });
                          },
                          child: Text('Cancel'),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text('Edit Profile'),
                        ),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isLoggingOut ? null : _logout,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoggingOut
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.red,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.logout, size: 20),
                                    SizedBox(width: 8),
                                    Text('Logout'),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 32),

                // Stats Summary
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Business Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(Icons.store, 'Florist', 'Verified'),
                            _buildStatItem(
                              Icons.verified_user,
                              'Status',
                              'Active',
                            ),
                            _buildStatItem(
                              Icons.calendar_today,
                              'Member Since',
                              '2024',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required bool editable,
    required TextEditingController controller,
    bool multiline = false,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.pink),
        title: editable
            ? multiline
                  ? TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: title,
                        border: InputBorder.none,
                      ),
                      maxLines: 3,
                    )
                  : TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: title,
                        border: InputBorder.none,
                      ),
                    )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value.isEmpty ? 'Not set' : value,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String title, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.pink, size: 24),
        SizedBox(height: 8),
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
