import 'dart:convert';

import 'package:application/models/order_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/basket_item.dart';
import '../provider/basket_provider.dart';
import 'package:provider/provider.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart'; // Add this import
import '../services/api_client.dart';

ImageProvider _basketImageProvider(String imageUrl) {
  final trimmed = imageUrl.trim();
  if (trimmed.isEmpty) {
    return const AssetImage('assets/placeholder.jpg');
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return NetworkImage(trimmed);
  }
  if (trimmed.startsWith('/')) {
    final baseUrl =
        ApiClient.primaryBaseUrl.endsWith('/')
            ? ApiClient.primaryBaseUrl.substring(
              0,
              ApiClient.primaryBaseUrl.length - 1,
            )
            : ApiClient.primaryBaseUrl;
    return NetworkImage('$baseUrl$trimmed');
  }
  if (trimmed.startsWith('assets/') || trimmed.startsWith('images/')) {
    return AssetImage(trimmed);
  }
  return const AssetImage('assets/placeholder.jpg');
}

Widget _buildItemThumbnail(
  String imageUrl, {
  double size = 80,
  double radius = 8,
  double iconSize = 24,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: Colors.grey[100],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image(
        image: _basketImageProvider(imageUrl),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            alignment: Alignment.center,
            child: Icon(
              Icons.local_florist,
              size: iconSize,
              color: Colors.grey[500],
            ),
          );
        },
      ),
    ),
  );
}

class BasketScreen extends StatefulWidget {
  const BasketScreen({super.key});

  @override
  State<BasketScreen> createState() => _BasketScreenState();
}

class _BasketScreenState extends State<BasketScreen> {
  final TextEditingController _wishlistLinkController =
      TextEditingController();

  @override
  void dispose() {
    _wishlistLinkController.dispose();
    super.dispose();
  }

  // Move these methods outside build but keep them as instance methods
  Widget _buildEmptyBasket(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Colors.grey[400],
          ),
          SizedBox(height: 20),
          Text(
            'Your basket is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Add some flowers to get started',
            style: TextStyle(color: Colors.grey[500]),
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Browse Flowers'),
          ),
        ],
      ),
    );
  }

  String _extractItemsParam(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    try {
      final uri = Uri.parse(trimmed);
      final param = uri.queryParameters['items'];
      if (param != null && param.isNotEmpty) {
        return param;
      }
    } catch (_) {}

    final index = trimmed.indexOf('items=');
    if (index != -1) {
      final start = index + 'items='.length;
      final end = trimmed.indexOf('&', start);
      return end == -1 ? trimmed.substring(start) : trimmed.substring(start, end);
    }

    return trimmed;
  }

  String _decodeBase64Url(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    switch (normalized.length % 4) {
      case 0:
        break;
      case 2:
        normalized += '==';
        break;
      case 3:
        normalized += '=';
        break;
      default:
        return '';
    }
    try {
      return utf8.decode(base64.decode(normalized));
    } catch (_) {
      return '';
    }
  }

  Map<String, dynamic>? _parseWishlistPayload(String input) {
    final encoded = _extractItemsParam(input);
    if (encoded.isEmpty) return null;
    final decoded = _decodeBase64Url(encoded);
    if (decoded.isEmpty) return null;
    try {
      final dynamic payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) return payload;
      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _addItemsFromLink(
    BuildContext context,
    BasketProvider basketProvider,
  ) {
    final input = _wishlistLinkController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste a wishlist link first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final payload = _parseWishlistPayload(input);
    final items = payload?['items'];
    if (payload == null || items is! List) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid wishlist link'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    var addedCount = 0;
    for (var i = 0; i < items.length; i++) {
      final raw = items[i];
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);

      final name = data['name']?.toString().trim();
      var flowerId = data['flowerId']?.toString().trim() ?? '';
      if (flowerId.isEmpty) {
        flowerId = 'shared-$i-${DateTime.now().millisecondsSinceEpoch}';
      }
      final price = _parseDouble(data['price']);
      final quantity = _parseInt(data['quantity']);
      final imageUrl =
          (data['imageUrl']?.toString().trim().isNotEmpty ?? false)
              ? data['imageUrl'].toString()
              : 'assets/placeholder.jpg';

      basketProvider.addItem(
        BasketItem(
          id: '${DateTime.now().millisecondsSinceEpoch}-$i',
          flowerId: flowerId,
          name: name?.isNotEmpty == true ? name! : 'Flower',
          price: price,
          quantity: quantity > 0 ? quantity : 1,
          imageUrl: imageUrl,
          floristId: data['floristId']?.toString(),
          floristName: data['floristName']?.toString(),
        ),
      );
      addedCount++;
    }

    if (addedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid items found in the link'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _wishlistLinkController.clear();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $addedCount items to your basket'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildLinkImportSection(
    BuildContext context,
    BasketProvider basketProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add wishlist link',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wishlistLinkController,
                  decoration: InputDecoration(
                    hintText: 'Paste wishlist link here',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addItemsFromLink(
                    context,
                    basketProvider,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _addItemsFromLink(context, basketProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBasketContent(
    BuildContext context,
    BasketProvider basketProvider,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'Items (${basketProvider.items.length})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Spacer(),
              Text(
                'Subtotal: ₸ ${basketProvider.totalPrice.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: basketProvider.items.length,
            itemBuilder: (context, index) {
              return _buildBasketItem(context, basketProvider, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBasketItem(
    BuildContext context,
    BasketProvider basketProvider,
    int index,
  ) {
    final item = basketProvider.items[index];
    final lineTotal = item.price * item.quantity;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              child: _buildItemThumbnail(
                item.imageUrl,
                size: 80,
                radius: 8,
                iconSize: 28,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '₸ ${item.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.pink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Line total: ₸ ${lineTotal.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove, size: 18),
                              onPressed: () {
                                if (item.quantity > 1) {
                                  basketProvider.updateQuantity(
                                    item.flowerId,
                                    item.quantity - 1,
                                  );
                                } else {
                                  basketProvider.removeItem(item.flowerId);
                                }
                              },
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '${item.quantity}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add, size: 18),
                              onPressed: () {
                                basketProvider.updateQuantity(
                                  item.flowerId,
                                  item.quantity + 1,
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          basketProvider.removeItem(item.flowerId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Item removed from basket'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearBasket(BuildContext context, BasketProvider basketProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Basket'),
        content: Text(
          'Are you sure you want to remove all items from your basket?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              basketProvider.clearBasket();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Basket cleared'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Clear All'),
          ),
        ],
      ),
    );
  }

  String _buildWishlistLink(
    BasketProvider basketProvider,
    AuthService authService,
  ) {
    final items = basketProvider.items
        .map(
          (item) => {
            'flowerId': item.flowerId,
            'name': item.name,
            'price': item.price,
            'quantity': item.quantity,
            'imageUrl': item.imageUrl,
            'floristName': item.floristName,
          },
        )
        .toList();

    final payload = {
      'items': items,
      'total': basketProvider.totalPrice,
      'currency': 'KZT',
      'from':
          authService.userData?['name'] ??
          authService.userData?['email'] ??
          '',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

    final jsonStr = jsonEncode(payload);
    final encoded = base64UrlEncode(utf8.encode(jsonStr));
    final baseUrl =
        ApiClient.primaryBaseUrl.endsWith('/')
            ? ApiClient.primaryBaseUrl.substring(
              0,
              ApiClient.primaryBaseUrl.length - 1,
            )
            : ApiClient.primaryBaseUrl;
    return '$baseUrl/wishlist?items=${Uri.encodeQueryComponent(encoded)}';
  }

  void _showWishlistLinkDialog(
    BuildContext context,
    BasketProvider basketProvider,
    AuthService authService,
  ) {
    if (basketProvider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your basket is empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final link = _buildWishlistLink(basketProvider, authService);
    final previewLength = 20;
    final preview =
        link.length <= previewLength
            ? link
            : '${link.substring(0, previewLength)}...';
    final rootContext = context;

    showDialog(
      context: rootContext,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Wishlist Link'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Share this link to send your wishlist.'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        preview,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${link.length} chars',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Full link will be copied.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    const SnackBar(
                      content: Text('Wishlist link copied'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Copy'),
              ),
            ],
          ),
    );
  }

  // screens/basket_screen.dart - Update the build method
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        return Consumer<BasketProvider>(
          builder: (context, basketProvider, child) {
            // Debug auth state
            if (kDebugMode) {
              print('=== Basket Screen Build ===');
              print('AuthService isLoggedIn: ${authService.isLoggedIn}');
              print('AuthService userId: ${authService.userId}');
              print(
                'AuthService token: ${authService.authToken?.substring(0, 20)}...',
              );
            }

            return Scaffold(
              appBar: AppBar(
                title: Text('Basket'),
                actions: [
                  if (basketProvider.items.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.delete_outline),
                      onPressed: () => _clearBasket(context, basketProvider),
                      tooltip: 'Clear basket',
                    ),
                ],
              ),
              body: Column(
                children: [
                  _buildLinkImportSection(context, basketProvider),
                  Expanded(
                    child: basketProvider.items.isEmpty
                        ? _buildEmptyBasket(context)
                        : _buildBasketContent(context, basketProvider),
                  ),
                ],
              ),
              bottomNavigationBar: basketProvider.items.isNotEmpty
                  ? _buildCheckoutBar(context, basketProvider, authService)
                  : null,
            );
          },
        );
      },
    );
  }

  // Update the _buildCheckoutBar method
  Widget _buildCheckoutBar(
    BuildContext context,
    BasketProvider basketProvider,
    AuthService authService,
  ) {
    // Add more detailed debug info
    if (kDebugMode) {
      print('=== Checkout Bar Auth State ===');
      print('isLoggedIn: ${authService.isLoggedIn}');
      print('userId: ${authService.userId}');
      print('userData: ${authService.userData}');
      print('authToken exists: ${authService.authToken != null}');
    }

    final lastItems =
        basketProvider.items.length > 3
            ? basketProvider.items.sublist(
                basketProvider.items.length - 3,
              )
            : basketProvider.items;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Last items',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Spacer(),
              Row(
                children: lastItems.map((item) {
                  return Container(
                    width: 32,
                    height: 32,
                    margin: EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[100],
                    ),
                    child: _buildItemThumbnail(
                      item.imageUrl,
                      size: 32,
                      radius: 8,
                      iconSize: 14,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '₸ ${basketProvider.totalPrice.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showWishlistLinkDialog(
                      context,
                      basketProvider,
                      authService,
                    );
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.pink,
                    side: const BorderSide(color: Colors.pink),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // Refresh auth state before checking
                    await authService.refreshAuthState();

                    if (!authService.isLoggedIn) {
                      if (kDebugMode) {
                        print('User not logged in, showing login prompt');
                      }
                      _showLoginPrompt(context);
                      return;
                    }

                    // Check if user has city information
                    if (authService.userData?['city'] == null ||
                        authService.userData?['city'].isEmpty) {
                      _showCityPrompt(context, authService, basketProvider);
                      return;
                    }

                    _checkout(context, basketProvider, authService);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    authService.isLoggedIn ? 'Checkout' : 'Login to Checkout',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Update the _checkout method
  void _checkout(
    BuildContext context,
    BasketProvider basketProvider,
    AuthService authService,
  ) async {
    // Refresh auth state one more time before checkout
    await authService.refreshAuthState();

    if (basketProvider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your basket is empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Triple-check authentication with detailed logging
    if (!authService.isLoggedIn) {
      if (kDebugMode) {
        print('=== Checkout Failed - Not Logged In ===');
        print('isLoggedIn: ${authService.isLoggedIn}');
        print('userId: ${authService.userId}');
        print('token exists: ${authService.authToken != null}');
      }
      _showLoginPrompt(context);
      return;
    }

    if (kDebugMode) {
      print('=== Proceeding to Checkout ===');
      print('User ID: ${authService.userId}');
      print('User Name: ${authService.userData?['name']}');
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          basketItems: basketProvider.items,
          totalPrice: basketProvider.totalPrice,
          authService: authService,
        ),
      ),
    );
  }

  // Update the _showLoginPrompt method
  void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Login Required'),
        content: Text('You need to log in to place an order.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to login screen
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
            ),
            child: Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  void _showCityPrompt(
    BuildContext context,
    AuthService authService,
    BasketProvider basketProvider,
  ) {
    final TextEditingController cityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('City Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please enter your city to proceed with checkout.'),
            SizedBox(height: 16),
            TextField(
              controller: cityController,
              decoration: InputDecoration(
                labelText: 'City',
                hintText: 'Enter your city',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (cityController.text.trim().isNotEmpty) {
                // Update user profile with city
                final result = await authService.updateProfile({
                  'city': cityController.text.trim(),
                });

                if (result['success'] == true) {
                  Navigator.pop(context);
                  _checkout(context, basketProvider, authService);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
            ),
            child: Text('Save & Continue'),
          ),
        ],
      ),
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  final List<BasketItem> basketItems;
  final double totalPrice;
  final AuthService authService;

  const CheckoutScreen({
    super.key,
    required this.basketItems,
    required this.totalPrice,
    required this.authService,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _addressController = TextEditingController();
  final OrderService _orderService = OrderService();
  bool _isPlacingOrder = false;
  String? _orderError;

  @override
  void initState() {
    super.initState();
    // Set default address from user data if available
    _addressController.text = widget.authService.userData?['address'] ?? '';
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    // Add debug logging
    if (kDebugMode) {
      print('=== Starting _placeOrder ===');
      print('User ID: ${widget.authService.userId}');
      print('Is logged in: ${widget.authService.isLoggedIn}');
      print('Basket items count: ${widget.basketItems.length}');
    }

    // Refresh auth state before placing order
    await widget.authService.refreshAuthState();

    if (!widget.authService.isLoggedIn) {
      if (kDebugMode) {
        print('User not logged in after refresh!');
        print('Auth token: ${widget.authService.authToken}');
        print('User data: ${widget.authService.userData}');
      }
      setState(() {
        _orderError = 'User not logged in. Please log in again.';
      });
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      setState(() {
        _orderError = 'Please enter delivery address';
      });
      return;
    }

    setState(() {
      _isPlacingOrder = true;
      _orderError = null;
    });

    try {
      // Debug: Check what's in the basket
      if (kDebugMode) {
        print('=== DEBUG: Basket Items ===');
        for (var item in widget.basketItems) {
          print('Item: ${item.name}, FloristId: ${item.floristId}');
        }
      }

      String? floristId;
      if (widget.basketItems.isNotEmpty) {
        for (var item in widget.basketItems) {
          if (item.floristId != null && item.floristId!.isNotEmpty) {
            floristId = item.floristId!;
            break;
          }
        }
      }

      if (floristId == null) {
        setState(() {
          _orderError =
              'Missing florist information. Please refresh and try again.';
          _isPlacingOrder = false;
        });
        return;
      }

      final floristIds =
          widget.basketItems
              .map((e) => e.floristId)
              .where((id) => id != null && id!.isNotEmpty)
              .toSet();
      if (floristIds.length > 1) {
        setState(() {
          _orderError =
              'Orders from multiple florists are not supported yet.';
          _isPlacingOrder = false;
        });
        return;
      }

      if (kDebugMode) {
        print('Using floristId: $floristId');
      }

      // Convert basket items to order items
      final orderItems = widget.basketItems.map((basketItem) {
        return OrderItem(
          flowerId: basketItem.flowerId,
          quantity: basketItem.quantity,
          price: basketItem.price,
        );
      }).toList();

      // Create order with floristId
      final order = Order(
        userId: widget.authService.userId ?? '',
        floristId: floristId,
        deliverId: null,
        status: 'pending',
        totalPrice: widget.totalPrice,
        city: widget.authService.userData?['city'] ?? 'Unknown',
        deliveryAddress: _addressController.text.trim(),
        items: orderItems,
        createdAt: DateTime.now(),
      );

      if (kDebugMode) {
        print('Order to create:');
        print('userId: ${order.userId}');
        print('floristId: ${order.floristId}');
        print('city: ${order.city}');
        final token = widget.authService.authToken;
        print('authToken length: ${token?.length ?? 0}');
      }

      // Call API to create order
      if (kDebugMode) {
        print('Calling _orderService.createOrder...');
      }

      final createdOrder = await _orderService.createOrder(
        order,
        authToken: widget.authService.authToken,
      );

      if (kDebugMode) {
        print('Order created successfully!');
        print('Order ID: ${createdOrder.id}');
        print('Order Number: ${createdOrder.orderNumber}');
      }

      // Clear basket - BUT ONLY AFTER SUCCESS
      if (kDebugMode) {
        print('Clearing basket...');
      }

      final basketProvider = Provider.of<BasketProvider>(
        context,
        listen: false,
      );
      basketProvider.clearBasket();

      // Show success and navigate back
      if (!mounted) {
        if (kDebugMode) {
          print('Widget not mounted, returning...');
        }
        return;
      }

      if (kDebugMode) {
        print('Showing success snackbar...');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order placed successfully! Order #${createdOrder.orderNumber ?? createdOrder.id}',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate back to home - BUT BE CAREFUL WITH THIS
      if (kDebugMode) {
        print('Navigating back to home...');
      }

      // Instead of popping all routes, use a safer approach
      Navigator.of(context).popUntil((route) {
        // Go back to home screen or basket screen
        return route.settings.name == '/' ||
            route.settings.name == '/home' ||
            route.settings.name == '/basket' ||
            route.isFirst;
      }); // Alternatively, just pop once to go back to basket screen
      // Navigator.pop(context); // This goes back to basket screen

      if (kDebugMode) {
        print('=== _placeOrder completed successfully ===');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('=== ERROR in _placeOrder ===');
        print('Error: $e');
        print('Stack trace: $stackTrace');
      }

      setState(() {
        _orderError = 'Failed to place order: $e';
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
        });
      }

      if (kDebugMode) {
        print('_placeOrder finally block executed');
        print('_isPlacingOrder set to false');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary Section
            Text(
              'Order Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (var item in widget.basketItems)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 50,
                          height: 50,
                          child: _buildItemThumbnail(
                            item.imageUrl,
                            size: 50,
                            radius: 8,
                            iconSize: 20,
                          ),
                        ),
                        title: Text(item.name),
                        subtitle: Text('Quantity: ${item.quantity}'),
                        trailing: Text(
                          '₸ ${(item.price * item.quantity).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.pink,
                          ),
                        ),
                      ),
                    Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₸ ${widget.totalPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Delivery Information Section
            Text(
              'Delivery Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Address',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        hintText: 'Enter your delivery address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 8),
                    if (widget.authService.userData?['city'] != null)
                      Text(
                        'City: ${widget.authService.userData?['city']}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // User Information Section
            Text(
              'Contact Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.pink.shade100,
                  child: Icon(Icons.person, color: Colors.pink),
                ),
                title: Text(widget.authService.userData?['name'] ?? 'User'),
                subtitle: Text(widget.authService.userData?['email'] ?? ''),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () {
                    // Navigate to profile/edit screen
                  },
                ),
              ),
            ),

            SizedBox(height: 24),

            // Error Display
            if (_orderError != null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _orderError!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 24),

            // Place Order Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPlacingOrder ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isPlacingOrder
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Processing Order...'),
                        ],
                      )
                    : Text(
                        'Place Order - ₸ ${widget.totalPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
