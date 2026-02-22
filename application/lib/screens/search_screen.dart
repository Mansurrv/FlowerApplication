import 'package:flutter/material.dart';
import 'dart:async';
import 'package:application/services/api_client.dart';
import 'dart:convert';

class FlowerSearchWidget extends StatefulWidget {
  const FlowerSearchWidget({super.key});

  @override
  _FlowerSearchWidgetState createState() => _FlowerSearchWidgetState();
}

class _FlowerSearchWidgetState extends State<FlowerSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Flower> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String _errorMessage = '';
  Timer? _debounceTimer;

  // Filter states
  String _selectedColor = 'All';
  String _selectedSeason = 'All';
  double _priceRange = 100.0;

  final List<String> _colors = [
    'All',
    'Red',
    'Pink',
    'White',
    'Yellow',
    'Purple',
    'Blue',
    'Orange',
  ];
  final List<String> _seasons = [
    'All',
    'Spring',
    'Summer',
    'Fall',
    'Winter',
    'Year-round',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // Load initial popular flowers
    _fetchPopularFlowers();

    // Listen to focus changes
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        setState(() {
          _isSearching = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isEmpty) {
        _fetchPopularFlowers();
      } else {
        _searchFlowers(_searchController.text);
      }
    });
  }

  Future<void> _searchFlowers(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final queryParameters = <String, String>{'q': query};

      if (_selectedColor != 'All') {
        queryParameters['color'] = _selectedColor.toLowerCase();
      }

      if (_selectedSeason != 'All') {
        queryParameters['season'] = _selectedSeason.toLowerCase();
      }

      queryParameters['maxPrice'] = _priceRange.toString();

      final response = await ApiClient.get(
        '/api/flowers/search',
        queryParameters: queryParameters,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['flowers'] ?? [];

        setState(() {
          _searchResults = results
              .map((flowerData) => Flower.fromJson(flowerData))
              .toList();
          _isLoading = false;
          _isSearching = true;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to search flowers. Status code: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Network error: ${error.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPopularFlowers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _isSearching = false;
    });

    try {
      final response = await ApiClient.get(
        '/api/flowers/popular',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['flowers'] ?? [];

        setState(() {
          _searchResults = results
              .map((flowerData) => Flower.fromJson(flowerData))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load flowers. Status code: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Network error: ${error.toString()}';
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    _fetchPopularFlowers();
  }

  void _applyFilters() {
    if (_searchController.text.isNotEmpty) {
      _searchFlowers(_searchController.text);
    } else {
      _fetchPopularFlowers();
    }
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Flowers',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Color filter
                  Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colors.map((color) {
                      bool isSelected = _selectedColor == color;
                      return ChoiceChip(
                        label: Text(color),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedColor = selected ? color : 'All';
                          });
                        },
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 20),

                  // Season filter
                  Text('Season', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _seasons.map((season) {
                      bool isSelected = _selectedSeason == season;
                      return ChoiceChip(
                        label: Text(season),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedSeason = selected ? season : 'All';
                          });
                        },
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 20),

                  // Price filter
                  Text(
                    'Max Price: \$${_priceRange.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 10),
                  Slider(
                    value: _priceRange,
                    min: 10,
                    max: 500,
                    divisions: 49,
                    label: '\$${_priceRange.toStringAsFixed(2)}',
                    onChanged: (value) {
                      setModalState(() {
                        _priceRange = value;
                      });
                    },
                  ),

                  SizedBox(height: 20),

                  // Apply filters button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _applyFilters();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Apply Filters'),
                    ),
                  ),

                  SizedBox(height: 10),

                  // Clear filters button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedColor = 'All';
                          _selectedSeason = 'All';
                          _priceRange = 100.0;
                        });
                        Navigator.pop(context);
                        _applyFilters();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Clear All Filters'),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar with filter button
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search flowers (e.g., roses, tulips, orchids)',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[600]),
                            onPressed: _clearSearch,
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.filter_list,
                            color: Colors.grey[600],
                          ),
                          onPressed: () => _showFilters(context),
                        ),
                      ],
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _searchFlowers(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16),

        // Status indicator
        if (_isSearching && _searchController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  'Search results for: ',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  '"${_searchController.text}"',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Text(
                  '${_searchResults.length} flowers found',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),

        // Loading indicator or results
        if (_isLoading)
          SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    _isSearching
                        ? 'Searching flowers...'
                        : 'Loading flowers...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else if (_errorMessage.isNotEmpty)
          Container(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 40, color: Colors.red),
                  SizedBox(height: 8),
                  Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchPopularFlowers,
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (_searchResults.isEmpty)
          SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isSearching ? Icons.search_off : Icons.power,
                    size: 50,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    _isSearching
                        ? 'No flowers found for "${_searchController.text}"'
                        : 'Search for flowers or browse popular ones',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  if (!_isSearching)
                    ElevatedButton(
                      onPressed: _fetchPopularFlowers,
                      child: Text('Refresh'),
                    ),
                ],
              ),
            ),
          )
        else
          // Results grid
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final flower = _searchResults[index];
              return _buildFlowerCard(flower);
            },
          ),
      ],
    );
  }

  Widget _buildFlowerCard(Flower flower) {
    return GestureDetector(
      onTap: () {
        // Navigate to flower details page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FlowerDetailPage(flower: flower),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flower image
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: Colors.grey[100],
                      child: flower.imageUrl.isNotEmpty
                          ? Image.network(
                              flower.imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.power,
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.power,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                            ),
                    ),
                  ),

                  // Favorite button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.favorite_border,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          // Add to favorites
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Flower details
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flower.name,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    flower.scientificName,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          flower.season,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          flower.color,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${flower.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                          fontSize: 14,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey[500],
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
}

// Flower Detail Page (basic implementation)
class FlowerDetailPage extends StatelessWidget {
  final Flower flower;

  const FlowerDetailPage({super.key, required this.flower});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(flower.name)),
      body: ListView(
        children: [
          // Add flower detail implementation here
        ],
      ),
    );
  }
}

// Flower model class
class Flower {
  final String id;
  final String name;
  final String scientificName;
  final String imageUrl;
  final double price;
  final String color;
  final String season;
  final String description;

  Flower({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.imageUrl,
    required this.price,
    required this.color,
    required this.season,
    required this.description,
  });

  factory Flower.fromJson(Map<String, dynamic> json) {
    return Flower(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      scientificName: json['scientificName'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      color: json['color'] ?? '',
      season: json['season'] ?? '',
      description: json['description'] ?? '',
    );
  }
}
