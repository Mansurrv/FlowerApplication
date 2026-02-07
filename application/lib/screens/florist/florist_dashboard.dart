import 'package:flutter/material.dart';
import 'package:application/screens/florist/florist_products_screen.dart';
import 'package:application/screens/florist/florist_orders_screen.dart';
import 'package:application/screens/florist/florist_profile_screen.dart';

class FloristDashboard extends StatefulWidget {
  final String authToken;
  final String userId;

  const FloristDashboard({
    super.key,
    required this.authToken,
    required this.userId,
  });

  @override
  State<FloristDashboard> createState() => _FloristDashboardState();
}

class _FloristDashboardState extends State<FloristDashboard> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _initializeScreens();
  }

  void _initializeScreens() {
    _screens.addAll([
      FloristProductsScreen(authToken: widget.authToken, userId: widget.userId),
      FloristOrdersScreen(
        authToken: widget.authToken,
        userId: widget.userId,
      ), // ADD userId HERE
      FloristProfileScreen(authToken: widget.authToken, userId: widget.userId),
    ]);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.pink,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.local_florist), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
      ),
    );
  }

  Widget _getAppBarTitle() {
    return SizedBox.shrink();
  }
}
