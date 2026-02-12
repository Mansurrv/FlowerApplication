import 'dart:async';
import 'package:application/screens/profile_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:application/services/api_client.dart';
import '../services/auth_service.dart';
import '../screens/basket_screen.dart';
import '../provider/basket_provider.dart';
import '../models/basket_item.dart';
import 'dart:convert';
import '../screens/orders_screen.dart'; // Add this import for the orders screen

class HomeScreen extends StatefulWidget {
  final AuthService authService;

  const HomeScreen({super.key, required this.authService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSearching = false;
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _allFlowers = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _searchResultsRaw = [];
  bool _isSearchLoading = false;
  String _searchError = '';
  Timer? _searchDebounce;
  late Future<List<Map<String, dynamic>>> _promotionsFuture;
  String _filterCategory = 'All';
  double _filterMaxPrice = 100000;
  bool _filterAvailableOnly = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _promotionsFuture = _fetchPromotions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _currentIndex = 1;
        Future.delayed(const Duration(milliseconds: 100), () {
          _searchFocusNode.requestFocus();
        });
        _loadAllFlowersForSearch();
      } else {
        _currentIndex = 0;
        _searchController.clear();
        _searchFocusNode.unfocus();
        _searchResults.clear();
        _searchError = '';
      }
    });
  }

  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();

      if (query.isEmpty) {
        _loadAllFlowersForSearch();
      } else if (query.length >= 2) {
        _searchFlowers(query);
      } else {
        setState(() {
          _searchResults.clear();
          _isSearchLoading = false;
        });
      }
    });
  }

  Future<void> _searchFlowers(String query) async {
    if (query.isEmpty || query.length < 2) {
      setState(() {
        _searchResults.clear();
        _isSearchLoading = false;
      });
      return;
    }

    setState(() {
      _isSearchLoading = true;
      _searchError = '';
    });

    try {
      final response = await ApiClient.get(
        '/api/flowers/search',
        queryParameters: {'q': query},
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true) {
          dynamic flowersData = data['flowers'];
          List<dynamic> flowersList = [];

          if (flowersData is List) {
            flowersList = flowersData;
          }

          setState(() {
            _searchResultsRaw = flowersList.map((flower) {
              if (flower is Map<String, dynamic>) {
                final floristId = flower['floristId'] is Map
                    ? flower['floristId']['_id']?.toString()
                    : flower['floristId']?.toString();
                return {
                  'id': flower['_id']?.toString() ?? '',
                  'name': flower['name']?.toString() ?? 'Flower',
                  'price': flower['price'] is num
                      ? (flower['price'] as num).toDouble()
                      : 0.0,
                  'image_url':
                      flower['image_url']?.toString() ??
                      'assets/placeholder.jpg',
                  'category': flower['categoryId'] is Map
                      ? (flower['categoryId']['name']?.toString() ?? 'General')
                      : 'General',
                  'description': flower['description']?.toString() ?? '',
                  'available': flower['available'] is bool
                      ? flower['available'] as bool
                      : true,
                  'floristId': floristId,
                  'florist': flower['floristId'] is Map
                      ? (flower['floristId']['shopName']?.toString() ??
                            'Unknown Florist')
                      : 'Unknown Florist',
                };
              }
              return {
                'id': '',
                'name': 'Unknown Flower',
                'price': 0.0,
                'image_url': 'assets/placeholder.jpg',
                'category': 'General',
                'description': '',
                'available': true,
                'floristId': null,
                'florist': 'Unknown Florist',
              };
            }).toList();
            _searchResults = _applyFilters(_searchResultsRaw);
            _isSearchLoading = false;
          });
        } else {
          setState(() {
            _searchError =
                data['message']?.toString() ?? 'Failed to search flowers';
            _isSearchLoading = false;
          });
        }
      } else {
        setState(() {
          _searchError =
              'Failed to search flowers. Status code: ${response.statusCode}';
          _isSearchLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _searchError = 'Network error: ${e.toString()}';
        _isSearchLoading = false;
      });
    }
  }

  Future<void> _loadAllFlowersForSearch() async {
    setState(() {
      _isSearchLoading = true;
      _searchError = '';
    });

    try {
      final response = await ApiClient.get(
        '/api/flowers',
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final mapped = data.map((flower) {
          if (flower is Map<String, dynamic>) {
            final floristId = flower['floristId'] is Map
                ? flower['floristId']['_id']?.toString()
                : flower['floristId']?.toString();
            return {
              'id': flower['_id']?.toString() ?? '',
              'name': flower['name']?.toString() ?? 'Flower',
              'price': flower['price'] is num
                  ? (flower['price'] as num).toDouble()
                  : 0.0,
              'image_url':
                  flower['image_url']?.toString() ?? 'assets/placeholder.jpg',
              'category': flower['categoryId'] is Map
                  ? (flower['categoryId']['name']?.toString() ?? 'General')
                  : 'General',
              'description': flower['description']?.toString() ?? '',
              'available': flower['available'] is bool
                  ? flower['available'] as bool
                  : true,
              'floristId': floristId,
              'florist': flower['floristId'] is Map
                  ? (flower['floristId']['shopName']?.toString() ??
                        'Unknown Florist')
                  : 'Unknown Florist',
            };
          }
          return {
            'id': '',
            'name': 'Unknown Flower',
            'price': 0.0,
            'image_url': 'assets/placeholder.jpg',
            'category': 'General',
            'description': '',
            'available': true,
            'floristId': null,
            'florist': 'Unknown Florist',
          };
        }).toList();

        setState(() {
          _allFlowers = mapped;
          _searchResultsRaw = mapped;
          _searchResults = _applyFilters(mapped);
          _isSearchLoading = false;
        });
      } else {
        setState(() {
          _searchError =
              'Failed to load flowers. Status code: ${response.statusCode}';
          _isSearchLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _searchError = 'Network error: ${e.toString()}';
        _isSearchLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> source) {
    return source.where((flower) {
      final matchesCategory =
          _filterCategory == 'All' ||
          (flower['category']?.toString() ?? '') == _filterCategory;
      final price = flower['price'] is num
          ? (flower['price'] as num).toDouble()
          : 0.0;
      final matchesPrice = price <= _filterMaxPrice;
      final available = flower['available'] == true;
      final matchesAvailable = !_filterAvailableOnly || available;
      return matchesCategory && matchesPrice && matchesAvailable;
    }).toList();
  }

  Future<List<String>> _fetchCategoryNames() async {
    try {
      final response = await ApiClient.get(
        '/api/categories',
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final names = data
            .map((c) => c is Map ? c['name']?.toString() ?? '' : '')
            .where((name) => name.isNotEmpty)
            .toList();
        return ['All', ...names];
      }
    } catch (_) {}
    return ['All'];
  }

  void _showSearchFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Category',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  FutureBuilder<List<String>>(
                    future: _fetchCategoryNames(),
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? ['All'];
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: items.map((name) {
                          final selected = _filterCategory == name;
                          return ChoiceChip(
                            label: Text(name),
                            selected: selected,
                            onSelected: (_) {
                              setModalState(() {
                                _filterCategory = name;
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Max Price: ₸ ${_filterMaxPrice.toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: _filterMaxPrice,
                    min: 1000,
                    max: 200000,
                    divisions: 40,
                    label: '₸ ${_filterMaxPrice.toStringAsFixed(0)}',
                    onChanged: (value) {
                      setModalState(() {
                        _filterMaxPrice = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Available only'),
                    value: _filterAvailableOnly,
                    onChanged: (value) {
                      setModalState(() {
                        _filterAvailableOnly = value;
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _searchResults = _applyFilters(_searchResultsRaw);
                        });
                      },
                      child: Text('Apply Filters'),
                    ),
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _filterCategory = 'All';
                          _filterMaxPrice = 100000;
                          _filterAvailableOnly = false;
                          _searchResults = _applyFilters(_searchResultsRaw);
                        });
                      },
                      child: Text('Clear Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchError = '';
    });
    _loadAllFlowersForSearch();
  }

  AppBar _buildAppBar(BuildContext context) {
    if (_isSearching) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _currentIndex = 0;
              _searchController.clear();
              _searchResults.clear();
              _searchError = '';
            });
          },
        ),
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Search flowers...',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey),
                      onPressed: _clearSearch,
                    ),
                  IconButton(
                    icon: Icon(Icons.filter_list, color: Colors.grey),
                    onPressed: _showSearchFilters,
                  ),
                ],
              ),
            ),
            autofocus: true,
            style: TextStyle(fontSize: 16),
            onChanged: (value) {
              _onSearchChanged();
            },
          ),
        ),
      );
    } else {
      return AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 80,
        backgroundColor: Colors.white,
        elevation: 1,
        title: Center(
          child: SizedBox(
            height: 40,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Image.asset('images/qwe.png', height: 50, width: 50),
                  ),
                ),
                Center(
                  child: Container(
                    margin: EdgeInsets.only(left: 40),
                    child: Text(
                      'InFloral',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.black),
            onPressed: _toggleSearch,
          ),
        ],
      );
    }
  }

  Widget _buildBody() {
    if (_isSearching) {
      return _buildSearchResults();
    } else {
      return SingleChildScrollView(
        child: Column(
          children: [
            _buildSpecialOffers(),
            _buildPromoStories(),
            _buildCategoryGrid(),
            _buildPopularProducts(),
          ],
        ),
      );
    }
  }

  Widget _buildSearchResults() {
    final query = _searchController.text.trim();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  query.isEmpty ? 'All Flowers' : 'Search Results',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (!_isSearchLoading)
                  Text(
                    '${_searchResults.length} results',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          if (_isSearchLoading)
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      query.isEmpty
                          ? 'Loading flowers...'
                          : 'Searching for "$query"...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else if (_searchError.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      _searchError,
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => query.isEmpty
                          ? _loadAllFlowersForSearch()
                          : _searchFlowers(query),
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_searchResults.isEmpty)
            SizedBox(
              height: 300,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'No flowers found for "$query"',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Try searching for something else',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                return _buildSearchResultCard(_searchResults[index], context);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(
    Map<String, dynamic> flower,
    BuildContext context,
  ) {
    final name = flower['name'] ?? 'Flower';
    final price = flower['price'] ?? 0.0;
    final imageUrl = flower['image_url'] ?? 'assets/placeholder.jpg';
    final category = flower['category'] ?? 'General';
    final available = flower['available'] ?? true;

    return GestureDetector(
      onTap: () {
        _showFlowerDetails(context, flower);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[200],
                image: DecorationImage(
                  image: _getImageProvider(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: !available
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SOLD OUT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    category,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₸ ${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.pink,
                          fontSize: 14,
                        ),
                      ),
                      if (available)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Text(
                            'Available',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

  Widget _buildSpecialOffers() {
    final List<Map<String, dynamic>> offerItems = [
      {
        'title': '',
        'subtitle': '',
        'buttonText': 'Buy Now',
        'imagePath': 'images/image.png',
        'repeatCount': 1,
      },
      {
        'title': '',
        'subtitle': '',
        'buttonText': 'Buy Now',
        'imagePath': 'images/imagecopy.png',
        'repeatCount': 1,
      },
      {
        'title': '',
        'subtitle': '',
        'buttonText': 'Shop Now',
        'imagePath': 'images/imagecopy2.png',
        'repeatCount': 1,
      },
    ];

    return Container(
      margin: EdgeInsets.all(4),
      padding: EdgeInsets.all(1),
      child: SizedBox(
        height: 200,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (var item in offerItems)
                for (int i = 0; i < item['repeatCount']; i++)
                  Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Container(
                      width: 300,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: AssetImage(item['imagePath']),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'],
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            item['subtitle'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          SizedBox(height: 50),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(0),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: Text(item['buttonText']),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPromotions() async {
    try {
      final response = await ApiClient.get(
        '/api/promotions',
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.map<Map<String, dynamic>>((item) {
            return {
              'title': item['title'] ?? '',
              'subtitle': item['subtitle'] ?? '',
              'image': item['imageUrl'] ?? '',
            };
          }).toList();
        }
      }
      return _defaultPromotions();
    } catch (_) {
      return _defaultPromotions();
    }
  }

  List<Map<String, dynamic>> _defaultPromotions() {
    return [
      {
        'title': '70% OFF',
        'subtitle': 'Special Discount',
        'image': 'images/image.png',
      },
      {
        'title': 'Free Gift',
        'subtitle': 'With Every Order',
        'image': 'images/imagecopy.png',
      },
      {
        'title': 'Bestseller',
        'subtitle': 'Popular Choice',
        'image': 'images/imagecopy2.png',
      },
      {'title': 'New', 'subtitle': '', 'image': 'images/image.png'},
    ];
  }

  void _showPromotionStories(
    int initialIndex,
    List<Map<String, dynamic>> stories,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) =>
          _PromotionStoryViewer(initialIndex: initialIndex, stories: stories),
    );
  }

  Widget _buildPromoStories() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _promotionsFuture,
      builder: (context, snapshot) {
        final stories = snapshot.hasData && snapshot.data!.isNotEmpty
            ? snapshot.data!
            : _defaultPromotions();

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Promotions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: stories.length,
                  separatorBuilder: (_, __) => SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final story = stories[index];
                    final imageUrl = story['image']?.toString() ?? '';
                    final title = story['title']?.toString() ?? '';

                    return Column(
                      children: [
                        InkWell(
                          onTap: () => _showPromotionStories(index, stories),
                          borderRadius: BorderRadius.circular(40),
                          child: Container(
                            width: 68,
                            height: 68,
                            padding: EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                            ),
                            child: ClipOval(
                              child: Image(
                                image: _getImageProvider(imageUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.black12,
                                    child: Icon(
                                      Icons.local_offer,
                                      color: Colors.black,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 6),
                        SizedBox(
                          width: 72,
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchCategories(),
      builder: (context, snapshot) {
        return Container(
          margin: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Categories',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                _buildLoadingGrid()
              else if (snapshot.hasError)
                _buildErrorState(snapshot.error.toString())
              else if (snapshot.hasData)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: snapshot.data!.map((category) {
                    return _buildCategoryItem(category);
                  }).toList(),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCategoryItem({'name': 'Roses'}),
                    _buildCategoryItem({'name': 'Tulips'}),
                    _buildCategoryItem({'name': 'Lilies'}),
                    _buildCategoryItem({'name': 'Orchids'}),
                    _buildCategoryItem({'name': 'Carnations'}),
                    _buildCategoryItem({'name': 'Sunflowers'}),
                    _buildCategoryItem({'name': 'Daisies'}),
                    _buildCategoryItem({'name': 'All Flowers'}),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCategories() async {
    try {
      final response = await ApiClient.get(
        '/api/categories',
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((category) {
          return {
            'id': category['_id'] ?? '',
            'name': category['name'] ?? 'Category',
          };
        }).toList();
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      rethrow;
    }
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    final categoryName = category['name'] ?? 'Category';
    final style = _getCategoryStyle(categoryName);

    return OutlinedButton(
      onPressed: () {
        print('Selected category: $categoryName');
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: style['color'].withOpacity(0.35)),
        backgroundColor: style['bgColor'],
        foregroundColor: style['color'],
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        categoryName,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Map<String, dynamic> _getCategoryStyle(String categoryName) {
    return {'color': Colors.black, 'bgColor': Colors.transparent};
  }

  Widget _buildLoadingGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(8, (index) {
        return Container(
          width: 90,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }

  Widget _buildErrorState(String error) {
    return Column(
      children: [
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
                  'Failed to load categories. Please try again.',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildCategoryItem({'name': 'Roses'}),
            _buildCategoryItem({'name': 'Tulips'}),
            _buildCategoryItem({'name': 'Lilies'}),
            _buildCategoryItem({'name': 'Orchids'}),
            _buildCategoryItem({'name': 'Carnations'}),
            _buildCategoryItem({'name': 'Sunflowers'}),
            _buildCategoryItem({'name': 'Daisies'}),
            _buildCategoryItem({'name': 'All Flowers'}),
          ],
        ),
      ],
    );
  }

  Widget _buildPopularProducts() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchPopularFlowers(),
      builder: (context, snapshot) {
        return Container(
          margin: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Flowers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      if (!_isSearching) {
                        _toggleSearch();
                      } else {
                        _searchController.clear();
                        _loadAllFlowersForSearch();
                      }
                    },
                    child: Text(
                      'See all',
                      style: TextStyle(color: Colors.pink),
                    ),
                  ),
                ],
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                _buildLoadingProducts()
              else if (snapshot.hasError)
                _buildProductsErrorState(snapshot.error.toString())
              else if (snapshot.hasData && snapshot.data!.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: snapshot.data!.map((flower) {
                      return _buildProductCard(flower, context);
                    }).toList(),
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildDefaultProductCard(
                        'assets/rose.jpg',
                        'Қызыл раушан',
                        '₸ 4,990',
                        'Roses',
                        context,
                      ),
                      _buildDefaultProductCard(
                        'assets/tulip.jpg',
                        'Тюльпандар',
                        '₸ 3,990',
                        'Tulips',
                        context,
                      ),
                      _buildDefaultProductCard(
                        'assets/lily.jpg',
                        'Лилиялар',
                        '₸ 5,490',
                        'Lilies',
                        context,
                      ),
                      _buildDefaultProductCard(
                        'assets/orchid.jpg',
                        'Орхидея',
                        '₸ 6,990',
                        'Orchids',
                        context,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPopularFlowers() async {
    try {
      final response = await ApiClient.get(
        '/api/flowers?sort=-createdAt&available=true',
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> data =
            decoded is Map<String, dynamic> && decoded['data'] is List
            ? decoded['data'] as List<dynamic>
            : decoded is List
            ? decoded
            : [];
        final mapped = data.map((flower) {
          final floristId = flower['floristId'] is Map
              ? flower['floristId']['_id']?.toString()
              : flower['floristId']?.toString();
          return {
            'id': flower['_id'] ?? '',
            'name': flower['name'] ?? 'Flower',
            'price': flower['price'] is num ? flower['price'].toDouble() : 0.0,
            'image_url': flower['image_url'] ?? 'assets/placeholder.jpg',
            'category': flower['categoryId']?['name'] ?? 'General',
            'description': flower['description'] ?? '',
            'available': flower['available'] ?? true,
            'floristId': floristId,
            'florist': flower['floristId']?['shopName'] ?? 'Unknown Florist',
          };
        }).toList();
        return mapped.take(5).toList();
      } else {
        final all = await _fetchAllFlowers();
        return all.take(5).toList();
      }
    } catch (e) {
      final all = await _fetchAllFlowers();
      return all.take(5).toList();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllFlowers() async {
    try {
      final response = await ApiClient.get(
        '/api/flowers',
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> data =
            decoded is Map<String, dynamic> && decoded['data'] is List
            ? decoded['data'] as List<dynamic>
            : decoded is List
            ? decoded
            : [];
        return data.map((flower) {
          final floristId = flower['floristId'] is Map
              ? flower['floristId']['_id']?.toString()
              : flower['floristId']?.toString();
          return {
            'id': flower['_id'] ?? '',
            'name': flower['name'] ?? 'Flower',
            'price': flower['price'] is num ? flower['price'].toDouble() : 0.0,
            'image_url': flower['image_url'] ?? 'assets/placeholder.jpg',
            'category': flower['categoryId']?['name'] ?? 'General',
            'description': flower['description'] ?? '',
            'available': flower['available'] ?? true,
            'floristId': floristId,
            'florist': flower['floristId']?['shopName'] ?? 'Unknown Florist',
          };
        }).toList();
      } else {
        throw Exception('Failed to load flowers');
      }
    } catch (e) {
      rethrow;
    }
  }

  Widget _buildProductCard(Map<String, dynamic> flower, BuildContext context) {
    final name = flower['name'] ?? 'Flower';
    final price = flower['price'] ?? 0.0;
    final imageUrl = flower['image_url'] ?? 'assets/placeholder.jpg';
    final category = flower['category'] ?? 'General';
    final available = flower['available'] ?? true;
    final florist = flower['florist'] ?? 'Unknown Florist';

    return GestureDetector(
      onTap: () {
        _showFlowerDetails(context, flower);
      },
      child: Container(
        width: 150,
        margin: EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[200],
                image: DecorationImage(
                  image: _getImageProvider(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: !available
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SOLD OUT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    category,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    florist,
                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₸ ${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.pink,
                          fontSize: 14,
                        ),
                      ),
                      if (available)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Text(
                            'Available',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

  Widget _buildDefaultProductCard(
    String image,
    String title,
    String price,
    String category,
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 150,
        margin: EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[200],
                image: DecorationImage(
                  image: AssetImage(image),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    category,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    price,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider _getImageProvider(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return NetworkImage(imageUrl);
    } else if (imageUrl.startsWith('assets/') ||
        imageUrl.startsWith('images/')) {
      return AssetImage(imageUrl);
    } else {
      return AssetImage('assets/placeholder.jpg');
    }
  }

  Widget _buildLoadingProducts() {
    return SizedBox(
      height: 200,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: List.generate(4, (index) {
          return Container(
            width: 150,
            margin: EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    color: Colors.grey.shade200,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 12,
                        color: Colors.grey.shade200,
                        margin: EdgeInsets.only(bottom: 4),
                      ),
                      Container(
                        width: 60,
                        height: 10,
                        color: Colors.grey.shade200,
                        margin: EdgeInsets.only(bottom: 6),
                      ),
                      Container(
                        width: 70,
                        height: 14,
                        color: Colors.grey.shade200,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildProductsErrorState(String error) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 40),
              SizedBox(height: 8),
              Text(
                'Failed to load products',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Please check your connection',
                style: TextStyle(color: Colors.red.shade600, fontSize: 12),
              ),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFlowerDetails(BuildContext context, Map<String, dynamic> flower) {
    final basketProvider = Provider.of<BasketProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  image: DecorationImage(
                    image: _getImageProvider(
                      flower['image_url'] ?? 'assets/placeholder.jpg',
                    ),
                    fit: BoxFit.cover,
                  ),
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
                          Text(
                            flower['name'] ?? 'Flower',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
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
                              (flower['available'] ?? true)
                                  ? 'Available'
                                  : 'Sold Out',
                              style: TextStyle(
                                color: (flower['available'] ?? true)
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '₸ ${(flower['price'] ?? 0.0).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.pink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        flower['description'] ?? 'No description available',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 16),
                      Divider(),
                      SizedBox(height: 8),
                      Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        flower['category'] ?? 'General',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Florist',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        flower['florist'] ?? 'Unknown Florist',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 24),
                      if (flower['available'] ?? true)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Extract florist information from the flower data
                              String? floristId;
                              String? floristName;

                              // Check different possible structures for florist data
                              if (flower['floristId'] != null) {
                                if (flower['floristId'] is Map) {
                                  floristId = flower['floristId']['_id']
                                      ?.toString();
                                  floristName =
                                      flower['floristId']['shopName'] ??
                                      flower['floristId']['name']?.toString();
                                } else if (flower['floristId'] is String) {
                                  floristId = flower['floristId'] as String;
                                }
                              }

                              // If not found in floristId, check florist field
                              if (floristId == null &&
                                  flower['florist'] != null) {
                                if (flower['florist'] is Map) {
                                  floristId = flower['florist']['_id']
                                      ?.toString();
                                  floristName =
                                      flower['florist']['shopName'] ??
                                      flower['florist']['name']?.toString();
                                } else if (flower['florist'] is String) {
                                  // If it's just a string ID
                                  floristId = flower['florist'] as String;
                                }
                              }

                              if (floristId == null || floristId.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'This flower is missing florist info. Please refresh.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              if (kDebugMode) {
                                print(
                                  'Adding to basket - Flower: ${flower['name']}, FloristId: $floristId',
                                );
                              }

                              basketProvider.addItem(
                                BasketItem(
                                  id: DateTime.now().millisecondsSinceEpoch
                                      .toString(),
                                  flowerId: flower['id'] ?? '',
                                  name: flower['name'] ?? 'Flower',
                                  price: (flower['price'] ?? 0.0).toDouble(),
                                  quantity: 1,
                                  imageUrl:
                                      flower['image_url'] ??
                                      'assets/placeholder.jpg',
                                  floristId:
                                      floristId!, // Now this should have a value
                                  floristName: floristName,
                                ),
                              );

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${flower['name']} added to cart',
                                  ),
                                  backgroundColor: Colors.pink,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Add to Cart'),
                          ),
                        ),
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

  BottomNavigationBar _buildBottomNavigationBar(BuildContext context) {
    final basketProvider = Provider.of<BasketProvider>(context);
    final basketItemCount = basketProvider.itemCount;

    final safeIndex = _currentIndex < 0 || _currentIndex > 4
        ? 0
        : _currentIndex;

    return BottomNavigationBar(
      currentIndex: safeIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.pink,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: [
        BottomNavigationBarItem(
          icon: Icon(
            Icons.home,
            color: safeIndex == 0 ? Colors.pink : Colors.grey,
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'images/searchIcon.png',
            width: 24,
            height: 24,
            color: safeIndex == 1 ? Colors.pink : Colors.grey,
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Stack(
            children: [
              Image.asset(
                'images/basketsIcon.png',
                width: 24,
                height: 24,
                color: safeIndex == 2 ? Colors.pink : Colors.grey,
              ),
              if (basketItemCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      basketItemCount > 9 ? '9+' : basketItemCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.receipt_long,
            color: safeIndex == 3 ? Colors.pink : Colors.grey,
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'images/profileIcon.png',
            width: 24,
            height: 24,
            color: safeIndex == 4 ? Colors.pink : Colors.grey,
          ),
          label: '',
        ),
      ],
      onTap: (index) async {
        setState(() {
          _currentIndex = index;
        });
        if (index == 1) {
          if (!_isSearching) {
            _toggleSearch();
          }
        } else if (index == 2) {
          setState(() {
            _isSearching = false;
          });
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BasketScreen()),
          );
          if (!mounted) return;
          setState(() {
            _currentIndex = 0;
          });
        } else if (index == 3) {
          // Navigate to Orders Screen
          setState(() {
            _isSearching = false;
          });
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  OrdersScreen(authService: widget.authService),
            ),
          );
          if (!mounted) return;
          setState(() {
            _currentIndex = 0;
          });
        } else if (index == 4) {
          // Navigate to Profile Screen
          setState(() {
            _isSearching = false;
          });
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ProfileScreen(authService: widget.authService),
            ),
          );
          if (!mounted) return;
          setState(() {
            _currentIndex = 0;
          });
        } else {
          setState(() {
            _isSearching = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }
}

ImageProvider _promotionImageProvider(String imageUrl) {
  if (imageUrl.startsWith('http')) {
    return NetworkImage(imageUrl);
  }
  if (imageUrl.startsWith('assets/') || imageUrl.startsWith('images/')) {
    return AssetImage(imageUrl);
  }
  return AssetImage('assets/placeholder.jpg');
}

class _PromotionStoryViewer extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;

  const _PromotionStoryViewer({
    required this.stories,
    required this.initialIndex,
  });

  @override
  State<_PromotionStoryViewer> createState() => _PromotionStoryViewerState();
}

class _PromotionStoryViewerState extends State<_PromotionStoryViewer> {
  late final PageController _controller;
  late int _index;
  Timer? _storyTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
    _startTimer();
  }

  void _startTimer() {
    _storyTimer?.cancel();
    _storyTimer = Timer(Duration(milliseconds: 1500), _advanceStory);
  }

  void _advanceStory() {
    if (!mounted) return;
    if (_index >= widget.stories.length - 1) {
      Navigator.pop(context);
      return;
    }

    _index += 1;
    _controller
        .animateToPage(
          _index,
          duration: Duration(milliseconds: 250),
          curve: Curves.easeOut,
        )
        .then((_) {
          if (mounted) {
            _startTimer();
          }
        });
  }

  @override
  void dispose() {
    _storyTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.stories.length,
          onPageChanged: (value) {
            _index = value;
            _startTimer();
          },
          itemBuilder: (context, index) {
            final story = widget.stories[index];
            final imageUrl = story['image']?.toString() ?? '';
            final title = story['title']?.toString() ?? '';
            final subtitle = story['subtitle']?.toString() ?? '';
            return Stack(
              children: [
                Positioned.fill(
                  child: Image(
                    image: _promotionImageProvider(imageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: Colors.black);
                    },
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 20,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
