import 'package:application/models/order_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/basket_item.dart';
import '../provider/basket_provider.dart';
import 'package:provider/provider.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart'; // Add this import

class BasketScreen extends StatelessWidget {
  const BasketScreen({super.key});

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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
                image: DecorationImage(
                  image: AssetImage(item.imageUrl),
                  fit: BoxFit.cover,
                ),
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
              body: basketProvider.items.isEmpty
                  ? _buildEmptyBasket(context)
                  : _buildBasketContent(context, basketProvider),
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.local_florist,
                            size: 16,
                            color: Colors.grey,
                          );
                        },
                      ),
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
          SizedBox(
            width: double.infinity,
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
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                authService.isLoggedIn ? 'Checkout' : 'Login to Checkout',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
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
      }

      // Call API to create order
      if (kDebugMode) {
        print('Calling _orderService.createOrder...');
      }

      final createdOrder = await _orderService.createOrder(order);

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
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[200],
                            image: DecorationImage(
                              image: AssetImage(item.imageUrl),
                              fit: BoxFit.cover,
                            ),
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
