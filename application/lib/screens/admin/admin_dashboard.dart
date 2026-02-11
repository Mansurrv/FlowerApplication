import 'package:flutter/material.dart';
import 'package:application/screens/admin/admin_user_management_screen.dart';
import 'package:application/screens/admin/admin_catalog_screen.dart';
import 'package:application/screens/profile_screen.dart';
import 'package:application/services/auth_service.dart';

class AdminDashboard extends StatefulWidget {
  final String authToken;
  final AuthService authService;

  const AdminDashboard({
    super.key,
    required this.authToken,
    required this.authService,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      AdminUserManagementScreen(
        authToken: widget.authToken,
        role: 'user',
        title: 'Users',
      ),
      AdminUserManagementScreen(
        authToken: widget.authToken,
        role: 'florist',
        title: 'Florists',
      ),
      AdminUserManagementScreen(
        authToken: widget.authToken,
        role: 'deliver',
        title: 'Delivery Partners',
      ),
      AdminCatalogScreen(authToken: widget.authToken),
      ProfileScreen(authService: widget.authService),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.pink,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.local_florist), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
      ),
    );
  }
}
