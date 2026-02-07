// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _error;
  String? _authToken;
  Map<String, dynamic>? _userData;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get authToken => _authToken;
  Map<String, dynamic>? get userData => _userData;

  // Update initializeFromStorage with better logging
  Future<void> initializeFromStorage() async {
    if (kDebugMode) {
      print('=== AuthService.initializeFromStorage() called ===');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
      final userDataString = prefs.getString('user_data');

      if (userDataString != null) {
        try {
          _userData = jsonDecode(userDataString);
        } catch (e) {
          if (kDebugMode) {
            print('Error decoding user_data: $e');
          }
          _userData = null;
        }
      }

      if (kDebugMode) {
        print('Loaded from storage:');
        print('  - Token exists: ${_authToken != null}');
        print('  - Token length: ${_authToken?.length}');
        print('  - User data exists: ${_userData != null}');
        print('  - User data keys: ${_userData?.keys}');
        print('  - User ID: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Storage initialization error: $e');
      }
      _authToken = null;
      _userData = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add currentUser getter
  User? get currentUser {
    if (_userData == null || _authToken == null) return null;
    return User.fromJson(_userData!);
  }

  // Add these getters for user properties
  String get userName => _userData?['name'] ?? 'Guest';
  String get userEmail => _userData?['email'] ?? 'No email';
  String get userCity => _userData?['city'] ?? 'Unknown city';

  // Initialize from storage with proper implementation

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_authToken != null) {
        print('Saving token to storage: ${_authToken!.substring(0, 20)}...');
        await prefs.setString('auth_token', _authToken!);
      } else {
        print('No token to save');
        await prefs.remove('auth_token');
      }

      if (_userData != null) {
        print('Saving user data: ${_userData!.keys}');
        await prefs.setString('user_data', jsonEncode(_userData!));
      } else {
        print('No user data to save');
        await prefs.remove('user_data');
      }

      // Verify save
      final savedToken = prefs.getString('auth_token');
      final savedUserData = prefs.getString('user_data');
      print('Verify save - Token saved: ${savedToken != null}');
      print('Verify save - User data saved: ${savedUserData != null}');
    } catch (e) {
      print('Error saving to storage: $e');
    }
  } // Clear storage

  Future<void> _clearStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing storage: $e');
      }
    }
  }

  // lib/services/auth_service.dart - Update these methods

  // Update the logout method to properly clear state
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Clear local state IMMEDIATELY
      _authToken = null;
      _userData = null;
      _error = null;

      // Clear stored data
      await _clearStorage();

      // Call API logout if needed
      await _apiService.logout();

      // Force notify listeners after clearing
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Logout error: $e');
      }
      // Still clear local state even if API fails
      _authToken = null;
      _userData = null;
      await _clearStorage();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update the isLoggedIn getter to be more reliable
  bool get isLoggedIn {
    if (kDebugMode) {
      print('=== isLoggedIn Check ===');
      print('Token exists: ${_authToken != null}');
      print('Token length: ${_authToken?.length}');
      print('User data exists: ${_userData != null}');
      print('User ID from data: ${_userData?['_id'] ?? _userData?['id']}');
      print('Has userId getter: ${userId != null}');
    }

    final loggedIn =
        _authToken != null &&
        _authToken!.isNotEmpty &&
        _userData != null &&
        userId != null;

    return loggedIn;
  }

  // Add this method to force refresh auth state
  Future<void> refreshAuthState() async {
    await initializeFromStorage();
    notifyListeners();
  }

  // Add fetchUserProfile method with proper implementation
  Future<Map<String, dynamic>> fetchUserProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_authToken == null) {
        _error = 'Not authenticated';
        return {'success': false, 'error': 'Not authenticated'};
      }

      // If you have an API endpoint, uncomment this:
      // final response = await _apiService.getProfile(_authToken!);
      // if (response['success'] == true) {
      //   _userData = response['data'];
      //   await _saveToStorage(); // Save updated data
      //   return response;
      // } else {
      //   _error = response['error'];
      //   return response;
      // }

      // For now, just return current data
      return {'success': true, 'data': _userData, 'message': 'Profile loaded'};
    } catch (e) {
      _error = 'Failed to fetch profile: $e';
      return {'success': false, 'error': 'Failed to fetch profile'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update your AuthService login method
  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('Attempting login for: $email');
      }

      final response = await _apiService.login(email, password);

      if (kDebugMode) {
        print('API Response: $response');
      }

      if (response['success'] == true) {
        // Extract token - try all possible response structures
        _authToken =
            response['token'] ??
            response['access_token'] ??
            response['data']?['token'] ??
            response['data']?['access_token'];

        // Extract user data - try all possible response structures
        _userData =
            response['user'] ??
            response['data']?['user'] ??
            response['data'] ??
            {'email': email};

        if (kDebugMode) {
          print('Token extracted: ${_authToken != null}');
          print('User data extracted: ${_userData != null}');
          print('User ID from data: ${_userData?['_id'] ?? _userData?['id']}');
        }

        // IMPORTANT: Ensure we have an ID
        if (_userData != null) {
          if (_userData!['_id'] == null && _userData!['id'] == null) {
            print('WARNING: User data missing ID!');
          }
        }

        // Save to storage
        await _saveToStorage();

        // Notify listeners after saving
        notifyListeners();

        return {
          'success': true,
          'message': response['message'] ?? 'Login successful',
          'data': response['data'] ?? response,
        };
      } else {
        _error = response['error'] ?? response['message'] ?? 'Login failed';
        return {'success': false, 'error': _error};
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Login error: $e');
        print('Stack trace: $stackTrace');
      }
      _error = 'An unexpected error occurred: $e';
      return {
        'success': false,
        'error': 'An unexpected error occurred: ${e.toString()}',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add this method to test storage
  Future<void> debugStorage() async {
    final prefs = await SharedPreferences.getInstance();
    print('=== Storage Debug ===');
    print('auth_token: ${prefs.getString('auth_token')?.substring(0, 30)}...');
    print('user_data: ${prefs.getString('user_data')}');
  }

  // Register method with storage
  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password, {
    required String role,
    required String city,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.register(
        name,
        email,
        password,
        role: role,
        city: city,
      );

      if (response['success'] == true) {
        // Optionally auto-login after registration
        // _authToken = response['data']['token'];
        // _userData = response['data']['user'];
        // await _saveToStorage();

        return {
          'success': true,
          'message': response['message'],
          'data': response['data'],
        };
      } else {
        _error = response['error'];
        return {'success': false, 'error': response['error']};
      }
    } catch (e) {
      _error = 'An unexpected error occurred: $e';
      return {'success': false, 'error': 'An unexpected error occurred'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String newPassword,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.resetPassword(email, newPassword);
      if (response['success'] == true) {
        return {'success': true, 'message': 'Password updated'};
      } else {
        _error = response['error'];
        return {'success': false, 'error': response['error']};
      }
    } catch (e) {
      _error = 'Failed to reset password: $e';
      return {'success': false, 'error': _error};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add updateProfile method with storage
  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> updates,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_authToken == null) {
        _error = 'Not authenticated';
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await _apiService.updateProfile(_authToken!, updates);
      if (response['success'] == true) {
        final data = response['data'];
        final user = data is Map ? data['user'] : null;
        if (user is Map<String, dynamic>) {
          _userData = {..._userData ?? {}, ...user};
        } else {
          _userData = {..._userData ?? {}, ...updates};
        }
        await _saveToStorage();
        return {
          'success': true,
          'message': 'Profile updated successfully',
          'data': _userData,
        };
      } else {
        _error = response['error'];
        return {'success': false, 'error': response['error']};
      }
    } catch (e) {
      _error = 'Failed to update profile: $e';
      return {'success': false, 'error': 'Failed to update profile'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get user ID safely
  String? get userId => _userData?['_id'] ?? _userData?['id'];
}

// User model class
class User {
  final String id;
  final String name;
  final String email;
  final String? city;
  final String? role;
  final String? profileImage;
  final Map<String, dynamic>? additionalData;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.city,
    this.role,
    this.profileImage,
    this.additionalData,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? 'Guest',
      email: json['email'] ?? '',
      city: json['city'],
      role: json['role'],
      profileImage: json['profileImage'],
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      '_id': id,
      'name': name,
      'email': email,
      'city': city,
      'role': role,
      'profileImage': profileImage,
      ...?additionalData,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? city,
    String? role,
    String? profileImage,
    Map<String, dynamic>? additionalData,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      city: city ?? this.city,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}
