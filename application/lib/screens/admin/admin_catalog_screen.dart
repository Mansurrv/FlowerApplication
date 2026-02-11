import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:application/services/api_client.dart';

class AdminCatalogScreen extends StatelessWidget {
  final String authToken;

  const AdminCatalogScreen({super.key, required this.authToken});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Catalog',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const TabBar(
                labelColor: Colors.pink,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'Categories'),
                  Tab(text: 'Cities'),
                  Tab(text: 'Promotions'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _AdminNamedCollection(
                      authToken: authToken,
                      title: 'Categories',
                      itemLabel: 'Category',
                      fetchPath: '/api/categories',
                      createPath: '/api/categories',
                      allowDelete: true,
                    ),
                    _AdminNamedCollection(
                      authToken: authToken,
                      title: 'Cities',
                      itemLabel: 'City',
                      fetchPath: '/api/cities',
                      createPath: '/api/cities',
                    ),
                    _AdminPromotionsCollection(authToken: authToken),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminNamedCollection extends StatefulWidget {
  final String authToken;
  final String title;
  final String itemLabel;
  final String fetchPath;
  final String createPath;
  final bool allowDelete;

  const _AdminNamedCollection({
    required this.authToken,
    required this.title,
    required this.itemLabel,
    required this.fetchPath,
    required this.createPath,
    this.allowDelete = false,
  });

  @override
  State<_AdminNamedCollection> createState() => _AdminNamedCollectionState();
}

class _AdminNamedCollectionState extends State<_AdminNamedCollection> {
  final TextEditingController _nameController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchItems() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiClient.get(
        widget.fetchPath,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data is List ? data : <dynamic>[];
        final normalized = list
            .map<Map<String, dynamic>>((item) => {
                  'id': (item['_id'] ?? item['id'] ?? '').toString(),
                  'name': (item['name'] ?? '').toString(),
                })
            .where((item) => item['name']!.isNotEmpty)
            .toList();
        normalized.sort((a, b) => a['name']!.compareTo(b['name']!));
        if (!mounted) return;
        setState(() {
          _items = normalized;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Failed to load ${widget.title.toLowerCase()} (${response.statusCode})';
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

  Future<void> _addItem() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Enter a name');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiClient.post(
        widget.createPath,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        body: json.encode({'name': name}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _nameController.clear();
        await _fetchItems();
        _showSnack('${widget.itemLabel} added');
      } else {
        String message = 'Failed to add ${widget.title.toLowerCase()}';
        try {
          final data = json.decode(response.body);
          if (data is Map) {
            if (data['message'] != null) {
              message = data['message'].toString();
            } else if (data['error'] != null) {
              message = data['error'].toString();
            }
          }
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack('Network error: ${e.toString()}');
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _deleteItem(String id, String name) async {
    if (!widget.allowDelete) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete ${widget.itemLabel}'),
          content: Text('Delete "$name"?'),
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

    if (confirmed != true) return;

    try {
      final response = await ApiClient.delete(
        '${widget.createPath}/$id',
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _items = _items.where((item) => item['id'] != id).toList();
        });
        _showSnack('Deleted');
      } else {
        _showSnack('Failed to delete');
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.title} (${_items.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _fetchItems,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Add ${widget.itemLabel}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _addItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
                  ? _buildError()
                  : _items.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return ListTile(
                              title: Text(item['name'] ?? ''),
                              trailing: widget.allowDelete
                                  ? IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deleteItem(
                                        item['id'] ?? '',
                                        item['name'] ?? '',
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
        ),
      ],
    );
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
              onPressed: _fetchItems,
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
            const Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No ${widget.title.toLowerCase()} yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminPromotionsCollection extends StatefulWidget {
  final String authToken;

  const _AdminPromotionsCollection({required this.authToken});

  @override
  State<_AdminPromotionsCollection> createState() =>
      _AdminPromotionsCollectionState();
}

class _AdminPromotionsCollectionState
    extends State<_AdminPromotionsCollection> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _fetchItems() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiClient.get(
        '/api/promotions',
        queryParameters: {'all': 'true'},
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data is List ? data : <dynamic>[];
        final normalized = list
            .map<Map<String, dynamic>>((item) => {
                  'id': (item['_id'] ?? item['id'] ?? '').toString(),
                  'title': (item['title'] ?? '').toString(),
                  'subtitle': (item['subtitle'] ?? '').toString(),
                  'imageUrl': (item['imageUrl'] ?? '').toString(),
                })
            .where((item) => item['title']!.isNotEmpty)
            .toList();
        if (!mounted) return;
        setState(() {
          _items = normalized;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Failed to load promotions (${response.statusCode})';
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

  Future<void> _addItem() async {
    final title = _titleController.text.trim();
    final subtitle = _subtitleController.text.trim();
    final imageUrl = _imageController.text.trim();

    if (title.isEmpty || imageUrl.isEmpty) {
      _showSnack('Title and image URL are required');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiClient.post(
        '/api/promotions',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        body: json.encode({
          'title': title,
          'subtitle': subtitle,
          'imageUrl': imageUrl,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _titleController.clear();
        _subtitleController.clear();
        _imageController.clear();
        await _fetchItems();
        _showSnack('Promotion added');
      } else {
        String message = 'Failed to add promotion';
        try {
          final data = json.decode(response.body);
          if (data is Map) {
            if (data['message'] != null) {
              message = data['message'].toString();
            } else if (data['error'] != null) {
              message = data['error'].toString();
            }
          }
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack('Network error: ${e.toString()}');
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _deleteItem(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete promotion'),
          content: Text('Delete \"$title\"?'),
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

    if (confirmed != true) return;

    try {
      final response = await ApiClient.delete(
        '/api/promotions/$id',
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _items = _items.where((item) => item['id'] != id).toList();
        });
        _showSnack('Promotion deleted');
      } else {
        _showSnack('Failed to delete promotion');
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Promotions (${_items.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _fetchItems,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _subtitleController,
                decoration: InputDecoration(
                  hintText: 'Subtitle (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _imageController,
                decoration: InputDecoration(
                  hintText: 'Image URL or asset path',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _addItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Add Promotion'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
                  ? _buildError()
                  : _items.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return ListTile(
                              leading: _PromoThumb(url: item['imageUrl'] ?? ''),
                              title: Text(item['title'] ?? ''),
                              subtitle: (item['subtitle'] ?? '').isNotEmpty
                                  ? Text(item['subtitle'])
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteItem(
                                  item['id'] ?? '',
                                  item['title'] ?? '',
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
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
              onPressed: _fetchItems,
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
            const Icon(Icons.local_offer, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No promotions yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoThumb extends StatelessWidget {
  final String url;

  const _PromoThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    final hasUrl = url.isNotEmpty;
    final isNetwork = url.startsWith('http');
    final isAsset = url.startsWith('assets/') || url.startsWith('images/');

    ImageProvider? provider;
    if (hasUrl && isNetwork) {
      provider = NetworkImage(url);
    } else if (hasUrl && isAsset) {
      provider = AssetImage(url);
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade200,
        image: provider != null
            ? DecorationImage(image: provider, fit: BoxFit.cover)
            : null,
      ),
      child: provider == null
          ? const Icon(Icons.local_offer, color: Colors.grey)
          : null,
    );
  }
}
