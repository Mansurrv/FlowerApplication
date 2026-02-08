import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:application/services/api_client.dart';

class ApiService {
  Future<void> logout() async {
    try {
      // If your backend has a logout endpoint, call it here
      // Example:
      // final response = await http.post(
      //   Uri.parse('${_baseUrl}/logout'),
      //   headers: {
      //     'Authorization': 'Bearer $_authToken',
      //     'Content-Type': 'application/json',
      //   },
      // );

      // If you don't have a logout endpoint, just return
      return;
    } catch (e) {
      // Log the error but don't throw it
      if (kDebugMode) {
        print('Logout API error: $e');
      }
      // Still return normally since logout should work even if API call fails
      return;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await ApiClient.post(
        '/api/auth/login',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data, 'message': 'Login successful'};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Login failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
        'statusCode': 0,
      };
    }
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password, {
    required String role,
    required String city, // ADD THIS
  }) async {
    try {
      final response = await ApiClient.post(
        '/api/auth/register',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          'city': city, // INCLUDE CITY IN REQUEST BODY
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
          'message': 'Registration successful',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Registration failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
        'statusCode': 0,
      };
    }
  }

  Future<Map<String, dynamic>> updateProfile(
    String authToken,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await ApiClient.put(
        '/api/users/profile',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Update failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
        'statusCode': 0,
      };
    }
  }

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String newPassword,
  ) async {
    try {
      final response = await ApiClient.post(
        '/api/auth/reset-password',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'email': email, 'newPassword': newPassword}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Reset failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
        'statusCode': 0,
      };
    }
  }
}
