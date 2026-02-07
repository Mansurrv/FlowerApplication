import 'package:flutter/material.dart';
import 'package:application/screens/deliver/deliver_orders_screen.dart';
import 'package:application/screens/profile_screen.dart';
import 'package:application/services/auth_service.dart';

class DeliverDashboard extends StatefulWidget {
  final String authToken;
  final String userId;
  final AuthService authService;

  const DeliverDashboard({
    super.key,
    required this.authToken,
    required this.userId,
    required this.authService,
  });

  @override
  State<DeliverDashboard> createState() => _DeliverDashboardState();
}

class _DeliverDashboardState extends State<DeliverDashboard> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DeliverOrdersScreen(authToken: widget.authToken, userId: widget.userId),
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
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
      ),
    );
  }
}
