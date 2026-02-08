import 'dart:convert';

import 'package:application/provider/basket_provider.dart';
import 'package:application/screens/admin/admin_dashboard.dart';
import 'package:application/screens/florist/florist_dashboard.dart';
import 'package:application/screens/deliver/deliver_dashboard.dart';
import 'package:application/screens/home_screen.dart';
import 'package:application/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authService = AuthService();
  await authService.initializeFromStorage();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<BasketProvider>(create: (_) => BasketProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Widget _getHomeScreenBasedOnRole(AuthService authService) {
    final userType = authService.userData?['role'] ?? 'user';
    final authToken = authService.authToken ?? '';
    final userId = authService.userId ?? '';

    if (kDebugMode) {
      print('User Role: $userType');
      print('User ID: $userId');
      print('Token exists: ${authToken.isNotEmpty}');
    }

    if (userType == 'admin' && authToken.isNotEmpty && userId.isNotEmpty) {
      return AdminDashboard(authToken: authToken, authService: authService);
    } else if (userType == 'florist' &&
        authToken.isNotEmpty &&
        userId.isNotEmpty) {
      return FloristDashboard(authToken: authToken, userId: userId);
    } else if (userType == 'deliver' &&
        authToken.isNotEmpty &&
        userId.isNotEmpty) {
      return DeliverDashboard(
        authToken: authToken,
        userId: userId,
        authService: authService,
      );
    } else {
      return HomeScreen(authService: authService);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return MaterialApp(
      title: 'Flower Shop',
      theme: ThemeData(primarySwatch: Colors.pink),
      home: authService.isLoggedIn
          ? _getHomeScreenBasedOnRole(authService)
          : AuthFlowScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({super.key});

  @override
  _AuthFlowScreenState createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  bool isLogin = true;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final headerPadding = isKeyboardVisible ? 24.0 : 60.0;
    final logoSize = isKeyboardVisible ? 40.0 : 56.0;
    final titleSize = isKeyboardVisible ? 24.0 : 32.0;
    final headerGap = isKeyboardVisible ? 8.0 : 12.0;
    final sectionSpacing = isKeyboardVisible ? 16.0 : 32.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- Logo Header ---
            AnimatedPadding(
              padding: EdgeInsets.symmetric(vertical: headerPadding),
              duration: const Duration(milliseconds: 200),
              child: Column(
                children: [
                  Image.asset(
                    'images/splash.png',
                    height: logoSize,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: headerGap),
                  Text(
                    'infloral',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // --- Tab Selector ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => isLogin = true);
                          _pageController.animateToPage(
                            0,
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isLogin ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isLogin
                                ? [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              'SIGN IN',
                              style: TextStyle(
                                fontWeight: isLogin
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isLogin ? Colors.pink : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => isLogin = false);
                          _pageController.animateToPage(
                            1,
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: !isLogin ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: !isLogin
                                ? [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              'REGISTER',
                              style: TextStyle(
                                fontWeight: !isLogin
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: !isLogin ? Colors.pink : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: sectionSpacing),

            // -- Forms --
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => isLogin = index == 0);
                },
                children: [
                  LoginForm(authService: authService),
                  RegisterForm(authService: authService),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  final AuthService authService; // Add this

  const LoginForm({super.key, required this.authService}); // Update constructor

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _showResetPasswordDialog() async {
    final emailController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Reset Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Enter new password',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          final newPassword = newPasswordController.text;
                          if (email.isEmpty || newPassword.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Please fill all fields'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          final result = await widget.authService.resetPassword(
                            email,
                            newPassword,
                          );
                          if (!mounted) return;

                          if (result['success'] == true) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Password updated'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            setDialogState(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result['error'] ?? 'Reset failed',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text('Reset'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Remove Provider.of line since we're getting it from constructor
    // final authService = Provider.of<AuthService>(context); // DELETE THIS

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
            // Email Field
            _MinimalTextField(
              controller: _emailController,
              hintText: 'Email address',
              icon: Icons.email_outlined,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                if (!value.contains('@')) return 'Invalid email';
                return null;
              },
            ),

            SizedBox(height: 16),

            // Password Field
            _MinimalTextField(
              controller: _passwordController,
              hintText: 'Password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                return null;
              },
            ),

            SizedBox(height: 24),

            // Forgot Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showResetPasswordDialog,
                style: TextButton.styleFrom(foregroundColor: Colors.pink),
                child: Text('Forgot password?', style: TextStyle(fontSize: 14)),
              ),
            ),

            SizedBox(height: 25),

            // Error Message
            if (_error != null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            if (_error != null) SizedBox(height: 16),

            // Sign In Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading || widget.authService.isLoading
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });

                          final result = await widget.authService.login(
                            _emailController.text.trim(),
                            _passwordController.text,
                          );

                          if (result['success'] == true) {
                            // Get user data directly from authService
                            final userType =
                                widget.authService.userData?['role'] ?? 'user';
                            final authToken =
                                widget.authService.authToken ?? ''; // CORRECTED
                            final userId = widget.authService.userId ?? '';

                            if (kDebugMode) {
                              print(
                                'Login successful - Role: $userType, ID: $userId',
                              );
                            }

                            // Navigate based on user type
                            if (userType == 'admin' &&
                                authToken.isNotEmpty &&
                                userId.isNotEmpty) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AdminDashboard(
                                    authToken: authToken,
                                    authService: widget.authService,
                                  ),
                                ),
                              );
                            } else if (userType == 'florist' &&
                                authToken.isNotEmpty &&
                                userId.isNotEmpty) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FloristDashboard(
                                    authToken: authToken,
                                    userId: userId,
                                  ),
                                ),
                              );
                            } else if (userType == 'deliver' &&
                                authToken.isNotEmpty &&
                                userId.isNotEmpty) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DeliverDashboard(
                                    authToken: authToken,
                                    userId: userId,
                                    authService: widget.authService,
                                  ),
                                ),
                              );
                            } else {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HomeScreen(
                                    authService: widget.authService,
                                  ),
                                ),
                              );
                            }

                            // Show welcome message with role
                            final roleText = userType == 'admin'
                                ? 'Admin'
                                : userType == 'florist'
                                    ? 'Florist'
                                    : userType == 'deliver'
                                        ? 'Delivery Partner'
                                        : 'User';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Welcome back, $roleText!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            setState(() {
                              _error = result['error'];
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result['error'] ?? 'Login failed',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }

                          setState(() => _isLoading = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading || widget.authService.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        'SIGN IN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterForm extends StatefulWidget {
  final AuthService authService;

  const RegisterForm({super.key, required this.authService});

  @override
  _RegisterFormState createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cityController = TextEditingController();

  // City data from API
  List<dynamic> _cities = [];
  List<dynamic> _filteredCities = [];
  bool _loadingCities = false;
  String? _cityError;
  bool _showCitySuggestions = false;

  // Role selection
  String? _selectedRole;
  final List<Map<String, dynamic>> _roles = [
    {
      'value': 'user',
      'label': 'User',
      'icon': Icons.person_outline,
      'description': 'Order flowers for yourself or as gifts',
    },
    {
      'value': 'florist',
      'label': 'Florist',
      'icon': Icons.local_florist_outlined,
      'description': 'Sell your floral arrangements',
    },
    {
      'value': 'deliver',
      'label': 'Delivery Partner',
      'icon': Icons.delivery_dining_outlined,
      'description': 'Deliver flowers to customers',
    },
  ];

  bool _isSubmitting = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  // Add this flag
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _cityController.addListener(_onCityChanged);
    _loadCities();
  }

  @override
  void dispose() {
    _isDisposed = true; // Set flag before disposing
    _cityController.removeListener(_onCityChanged);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  // Safe setState method
  void _safeSetState(VoidCallback fn) {
    if (mounted && !_isDisposed) {
      setState(fn);
    }
  }

  // Load cities from API
  Future<void> _loadCities() async {
    if (!mounted) return;

    _safeSetState(() {
      _loadingCities = true;
      _cityError = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://localhost:4040/api/cities'),
        headers: {'Accept': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle different API response structures
        List<dynamic> citiesList = [];

        if (data is List) {
          citiesList = data;
        } else if (data['data'] is List) {
          citiesList = data['data'];
        } else if (data['cities'] is List) {
          citiesList = data['cities'];
        }

        _safeSetState(() {
          _cities = citiesList;
          _filteredCities = citiesList;
        });
      } else {
        _safeSetState(() {
          _cityError = 'Failed to load cities (${response.statusCode})';
        });
      }
    } catch (e) {
      if (!mounted) return;
      _safeSetState(() {
        _cityError = 'Failed to load cities: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        _safeSetState(() {
          _loadingCities = false;
        });
      }
    }
  }

  void _onCityChanged() {
    if (!mounted) return;

    final query = _cityController.text.toLowerCase();

    if (query.isEmpty) {
      _safeSetState(() {
        _filteredCities = _cities;
        _showCitySuggestions = false;
      });
      return;
    }

    _safeSetState(() {
      _filteredCities = _cities.where((city) {
        final cityName = _getCityName(city).toLowerCase();
        return cityName.contains(query);
      }).toList();
      _showCitySuggestions = _filteredCities.isNotEmpty;
    });
  }

  String _getCityName(dynamic city) {
    if (city is String) {
      return city;
    } else if (city is Map) {
      return city['name'] ?? city['city'] ?? city['title'] ?? '';
    }
    return city.toString();
  }

  void _selectCity(dynamic city) {
    if (!mounted) return;

    final cityName = _getCityName(city);
    _safeSetState(() {
      _cityController.text = cityName;
      _showCitySuggestions = false;
    });

    // Close keyboard
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name Field
              _MinimalTextField(
                controller: _nameController,
                hintText: 'Full name',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value.length < 2) return 'Name is too short';
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Email Field
              _MinimalTextField(
                controller: _emailController,
                hintText: 'Email address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return 'Invalid email';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Password Field
              _MinimalTextField(
                controller: _passwordController,
                hintText: 'Password',
                icon: Icons.lock_outline,
                isPassword: !_showPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    _safeSetState(() => _showPassword = !_showPassword);
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value.length < 6) return 'Minimum 6 characters';
                  if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
                    return 'Include letters & numbers';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Confirm Password Field
              _MinimalTextField(
                controller: _confirmPasswordController,
                hintText: 'Confirm password',
                icon: Icons.lock_reset_outlined,
                isPassword: !_showConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    _safeSetState(
                      () => _showConfirmPassword = !_showConfirmPassword,
                    );
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // City Field with API Suggestions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      _MinimalTextField(
                        controller: _cityController,
                        hintText: 'City',
                        icon: Icons.location_city_outlined,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (value.length < 2) return 'Enter a valid city';
                          return null;
                        },
                      ),

                      if (_loadingCities)
                        Positioned(
                          right: 12,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.pink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (_cityError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.orange,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _cityError!,
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadCities,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(0, 0),
                            ),
                            child: Text(
                              'Retry',
                              style: TextStyle(
                                color: Colors.pink,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_showCitySuggestions && _filteredCities.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      constraints: BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredCities.length,
                        itemBuilder: (context, index) {
                          final city = _filteredCities[index];
                          final cityName = _getCityName(city);

                          return ListTile(
                            leading: Icon(Icons.location_on_outlined, size: 20),
                            title: Text(
                              cityName,
                              style: TextStyle(fontSize: 14),
                            ),
                            onTap: () => _selectCity(city),
                            dense: true,
                            visualDensity: VisualDensity.compact,
                          );
                        },
                      ),
                    ),
                ],
              ),

              SizedBox(height: 24),

              // Role Selection Section
              Text(
                'Select Your Role',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Choose how you want to use InFloral',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 16),

              // Role Options
              ..._roles.map((role) {
                final bool isSelected = _selectedRole == role['value'];
                return GestureDetector(
                  onTap: () {
                    _safeSetState(() => _selectedRole = role['value']);
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.pink : Colors.grey[200]!,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.pink.withOpacity(0.1)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            role['icon'],
                            color: isSelected ? Colors.pink : Colors.grey[600],
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                role['label'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                role['description'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Colors.pink,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                );
              }),

              // Role Validation Error
              if (_selectedRole == null && _isSubmitting)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Please select a role',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              SizedBox(height: 32),

              // Terms & Conditions Checkbox
              Row(
                children: [
                  Checkbox(
                    value: true,
                    onChanged: (value) {},
                    activeColor: Colors.pink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        children: [
                          TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: TextStyle(
                              color: Colors.pink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: Colors.pink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Error Message
              if (widget.authService.error != null)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.authService.error!,
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              if (widget.authService.error != null) SizedBox(height: 16),

              // Create Account Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: widget.authService.isLoading || _isSubmitting
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            if (_selectedRole == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please select a role'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            _safeSetState(() => _isSubmitting = true);

                            final result = await widget.authService.register(
                              _nameController.text.trim(),
                              _emailController.text.trim(),
                              _passwordController.text,
                              role: _selectedRole!,
                              city: _cityController.text.trim(),
                            );

                            if (!mounted) return;

                            if (result['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Account created successfully!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // Clear form
                              _nameController.clear();
                              _emailController.clear();
                              _passwordController.clear();
                              _confirmPasswordController.clear();
                              _cityController.clear();
                              _safeSetState(() => _selectedRole = null);

                              // Switch to login tab
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && context.mounted) {
                                  final authFlowScreen = context
                                      .findAncestorStateOfType<
                                        _AuthFlowScreenState
                                      >();
                                  authFlowScreen?.setState(() {
                                    authFlowScreen.isLogin = true;
                                    authFlowScreen._pageController
                                        .animateToPage(
                                          0,
                                          duration: Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                  });
                                }
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result['error'] ?? 'Registration failed',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }

                            if (mounted) {
                              _safeSetState(() => _isSubmitting = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: widget.authService.isLoading || _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          'CREATE ACCOUNT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              SizedBox(height: 24),

              // Already have account text
              Center(
                child: GestureDetector(
                  onTap: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && context.mounted) {
                        final authFlowScreen = context
                            .findAncestorStateOfType<_AuthFlowScreenState>();
                        authFlowScreen?.setState(() {
                          authFlowScreen.isLogin = true;
                          authFlowScreen._pageController.animateToPage(
                            0,
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        });
                      }
                    });
                  },
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      children: [
                        TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Sign In',
                          style: TextStyle(
                            color: Colors.pink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimalTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const _MinimalTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    this.validator,
    this.keyboardType,
    this.suffixIcon,
  });

  @override
  __MinimalTextFieldState createState() => __MinimalTextFieldState();
}

class __MinimalTextFieldState extends State<_MinimalTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword && _obscureText,
      keyboardType: widget.keyboardType,
      style: TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(color: Colors.grey),
        prefixIcon: Icon(widget.icon, size: 20, color: Colors.grey),
        suffixIcon:
            widget.suffixIcon ??
            (widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() => _obscureText = !_obscureText);
                    },
                  )
                : null),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        errorStyle: TextStyle(fontSize: 12),
      ),
      validator: widget.validator,
    );
  }
}
