import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:application/services/api_client.dart';

class FloristProductsScreen extends StatefulWidget {
  final String authToken;
  final String userId;

  const FloristProductsScreen({
    super.key,
    required this.authToken,
    required this.userId,
  });

  @override
  State<FloristProductsScreen> createState() => _FloristProductsScreenState();
}

class _FloristProductsScreenState extends State<FloristProductsScreen> {
  List<Map<String, dynamic>> _flowers = [];
  bool _isLoading = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _categories = [];

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  String? _selectedCategoryId;
  bool _available = true;
  String? _editingFlowerId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<void> _loadData() async {
    await _fetchCategories();
    await _fetchFlowers();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await ApiClient.get(
        '/api/categories',
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _safeSetState(() {
          _categories = data.map((category) {
            return {
              'id': category['_id'] ?? '',
              'name': category['name'] ?? 'Category',
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  Future<void> _fetchFlowers() async {
    _safeSetState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (kDebugMode) {
        print('Fetching florist flowers...');
      }

      final response = await ApiClient.get(
        '/api/florists/flowers',
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      if (kDebugMode) {
        print('Status Code: ${response.statusCode}');
        print('Response: ${response.body}');
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        _safeSetState(() {
          _flowers = data.map((flower) {
            // Handle both image_url and imageUrl field names
            final imageUrl = flower['image_url'] ?? flower['imageUrl'] ?? '';

            return {
              'id': flower['_id'] ?? '',
              'name': flower['name'] ?? 'Flower',
              'price': flower['price'] is num
                  ? (flower['price'] as num).toDouble()
                  : 0.0,
              'image_url': imageUrl,
              'category': flower['categoryId'] is Map
                  ? (flower['categoryId']['name']?.toString() ?? 'General')
                  : 'General',
              'categoryId': flower['categoryId'] is Map
                  ? flower['categoryId']['_id']?.toString()
                  : flower['categoryId']?.toString(),
              'description': flower['description'] ?? '',
              'available': flower['available'] is bool
                  ? flower['available'] as bool
                  : true,
              'city': flower['city'] ?? '',
              'createdAt': flower['createdAt'] ?? '',
            };
          }).toList();
          _isLoading = false;
        });

        if (kDebugMode) {
          print('Loaded ${_flowers.length} flowers');
        }
      } else if (response.statusCode == 401) {
        _safeSetState(() {
          _errorMessage = 'Authentication failed. Please login again.';
          _isLoading = false;
        });
      } else if (response.statusCode == 403) {
        _safeSetState(() {
          _errorMessage = 'Access denied. You are not a florist.';
          _isLoading = false;
        });
      } else {
        _safeSetState(() {
          _errorMessage =
              'Failed to load flowers (Status: ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching flowers: $e');
      }
      _safeSetState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? flower}) {
    _editingFlowerId = flower?['id'];

    if (flower != null) {
      _nameController.text = flower['name'] ?? '';
      _priceController.text = (flower['price'] ?? 0.0).toString();
      _descriptionController.text = flower['description'] ?? '';
      _imageUrlController.text = flower['image_url'] ?? '';
      _available = flower['available'] ?? true;
      _selectedCategoryId = flower['categoryId'];
    } else {
      _clearForm();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(flower == null ? 'Add New Flower' : 'Edit Flower'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Flower Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price (₸)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text('Select Category')),
                  ..._categories.map((category) {
                    return DropdownMenuItem(
                      value: category['id'],
                      child: Text(category['name']),
                    );
                  }),
                ],
                onChanged: (value) {
                  _safeSetState(() {
                    _selectedCategoryId = value;
                  });
                },
              ),
              SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 12),
              TextField(
                controller: _imageUrlController,
                decoration: InputDecoration(
                  labelText: 'Image URL',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              SwitchListTile(
                title: Text('Available'),
                value: _available,
                onChanged: (value) {
                  _safeSetState(() {
                    _available = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : () {
                    if (_editingFlowerId == null) {
                      _addFlower();
                    } else {
                      _updateFlower();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? CircularProgressIndicator(color: Colors.white)
                : Text(_editingFlowerId == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _addFlower() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      _showSnackBar('Name and price are required');
      return;
    }

    _safeSetState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient.post(
        '/api/flowers',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        body: json.encode({
          'name': _nameController.text,
          'price': double.parse(_priceController.text),
          'description': _descriptionController.text,
          'image_url': _imageUrlController.text,
          'categoryId': _selectedCategoryId,
          'available': _available,
          'floristId': widget.userId,
        }),
      );

      if (response.statusCode == 201) {
        _clearForm();
        Navigator.pop(context);
        await _fetchFlowers();
        _showSnackBar('Flower added successfully');
      } else {
        _showSnackBar('Failed to add flower');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateFlower() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      _showSnackBar('Name and price are required');
      return;
    }

    _safeSetState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient.put(
        '/api/flowers/$_editingFlowerId',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        body: json.encode({
          'name': _nameController.text,
          'price': double.parse(_priceController.text),
          'description': _descriptionController.text,
          'image_url': _imageUrlController.text,
          'categoryId': _selectedCategoryId,
          'available': _available,
        }),
      );

      if (response.statusCode == 200) {
        _clearForm();
        Navigator.pop(context);
        await _fetchFlowers();
        _showSnackBar('Flower updated successfully');
      } else {
        _showSnackBar('Failed to update flower');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      _safeSetState(() {
        _isLoading = false;
        _editingFlowerId = null;
      });
    }
  }

  Future<void> _deleteFlower(String flowerId) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Flower'),
        content: Text('Are you sure you want to delete this flower?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _safeSetState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient.delete(
        '/api/flowers/$flowerId',
        headers: {'Authorization': 'Bearer ${widget.authToken}'},
      );

      if (response.statusCode == 200) {
        await _fetchFlowers();
        _showSnackBar('Flower deleted successfully');
      } else {
        _showSnackBar('Failed to delete flower');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  void _clearForm() {
    _nameController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _imageUrlController.clear();
    _selectedCategoryId = null;
    _available = true;
    _editingFlowerId = null;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.pink),
    );
  }

  Widget _buildFlowerCard(Map<String, dynamic> flower) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
            image: DecorationImage(
              image: flower['image_url']?.isNotEmpty == true
                  ? NetworkImage(flower['image_url'])
                  : AssetImage('assets/placeholder.jpg') as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: Text(
          flower['name'],
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text('₸ ${(flower['price'] ?? 0.0).toStringAsFixed(0)}'),
            SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (flower['available'] ?? true)
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: (flower['available'] ?? true)
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                    ),
                  ),
                  child: Text(
                    (flower['available'] ?? true) ? 'Available' : 'Sold Out',
                    style: TextStyle(
                      fontSize: 10,
                      color: (flower['available'] ?? true)
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  flower['category'],
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showAddEditDialog(flower: flower);
            } else if (value == 'delete') {
              _deleteFlower(flower['id']);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'My Flowers (${_flowers.length})',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: Icon(Icons.add, size: 20),
                label: Text('Add Flower'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading && _flowers.isEmpty
              ? Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty && _flowers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchFlowers,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _flowers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_florist_outlined,
                        size: 60,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No flowers yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add your first flower to get started',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _showAddEditDialog(),
                        child: Text('Add First Flower'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchFlowers,
                  child: ListView.builder(
                    itemCount: _flowers.length,
                    itemBuilder: (context, index) {
                      return _buildFlowerCard(_flowers[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }
}
