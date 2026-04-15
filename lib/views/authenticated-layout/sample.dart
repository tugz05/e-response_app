import 'dart:async';
import 'package:e_response_app_nemsu/helpers/logout.dart';
import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/services/shared_preferences/SharedPreferencesService.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/components/drawerheader.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/dashboard.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/pages.dart';
import 'package:flutter/material.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SharedPreferencesService _prefsService = SharedPreferencesService();
  String? _email;
  String? _name;
  int _currentIndex = 0; // Track the selected menu index
  List<Widget> _pages = []; // Pages to display

  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _resetInactivityTimer();
    _initializePages(); // Initialize pages with unique keys
  }


  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    final credentials = await _prefsService.getCredentials();
    setState(() {
      _email = credentials['email'];
      _name = credentials['name'];
    });
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(days: 7), () {
      // Auto logout after 10 minutes of inactivity
      LogoutModule.performLogout(context);
    });
  }

  void _initializePages() {
    _pages = [
      Dashboard(),
      Pages(key: UniqueKey(), apiUrl: "api/v1/news", titleText: "Latest News"),
      Pages(
        key: UniqueKey(),
        apiUrl: "api/v1/emergency-preparedness",
        titleText: "Read the Emergency Preparedness",
      ),
      Pages(
        key: UniqueKey(),
        apiUrl: "api/v1/safety-tips",
        titleText: "Read the Safety Tips",
      ),
      ProfilePage(),
      ProfilePage(),
      ProfilePage(),
    ];
  }

  final List<Map<String, dynamic>> _menuItems = [
    {
      'icon': Icons.dashboard,
      'title': 'Dashboard',
    },
    {
      'icon': Icons.article,
      'title': 'News',
    },
    {
      'icon': Icons.emergency,
      'title': 'Emergency Preparedness',
    },
    {
      'icon': Icons.shield,
      'title': 'Safety Tips',
    },
    {
      'icon': Icons.feedback,
      'title': 'Feedback',
    },
    {
      'icon': Icons.phone,
      'title': 'Contact Us',
    },
    {
      'icon': Icons.info,
      'title': 'About Us',
    },
  ];

  void _onSelectMenu(int index) {
    setState(() {
      _currentIndex = index;
      _initializePages(); // Reinitialize pages with unique keys for dynamic refresh
    });
    Navigator.pop(context); // Close the drawer after selection
  }

  Future<bool> _onWillPop() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              LogoutModule.performLogout(context);
            },
            child: Text('Logout'),
          ),
        ],
      ),
    );
    return shouldLogout ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _resetInactivityTimer,
        onPanDown: (_) => _resetInactivityTimer(),
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                _menuItems[_currentIndex]['title'], // Update title dynamically
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFamily: 'Roboto',
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, RouteManager.userPage);
                  },
                  child: Icon(Icons.account_circle_rounded)),
              ),
            ],
          ),
          drawer: Drawer(
            child: Column(
              children: <Widget>[
                DrawerHeaderContent(name: '$_name', email: '$_email'),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(bottom: 2),
                    children: _menuItems.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, dynamic> menuItem = entry.value;

                      return ListTile(
                        leading: Icon(
                          menuItem['icon'],
                          color: AppColors.primary,
                        ),
                        title: Text(
                          menuItem['title'],
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                          ),
                        ),
                        onTap: () => _onSelectMenu(index),
                      );
                    }).toList(),
                  ),
                ),
                LogoutModule(),
              ],
            ),
          ),
          body: _pages[_currentIndex], // Dynamically display the selected page
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Profile Page'),
    );
  }
}
