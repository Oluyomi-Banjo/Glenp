import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/models/user.dart';
import 'package:attendance_app/utils/constants.dart';

class AuthService extends ChangeNotifier {
  final SharedPreferences _prefs;
  User? _currentUser;
  String? _token;
  bool _isLoading = false;

  AuthService(this._prefs) {
    _loadUserFromPrefs();
  }

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  bool get isStudent => _currentUser?.role == 'student';
  bool get isEducator => _currentUser?.role == 'educator';

  Future<void> _loadUserFromPrefs() async {
    _token = _prefs.getString('token');
    final userJson = _prefs.getString('user');

    if (userJson != null) {
      _currentUser = User.fromJson(jsonDecode(userJson));
    }

    notifyListeners();
  }

  Future<void> _saveUserToPrefs() async {
    if (_currentUser != null) {
      await _prefs.setString('user', jsonEncode(_currentUser!.toJson()));
    }

    if (_token != null) {
      await _prefs.setString('token', _token!);
    }
  }

  Future<Map<String, dynamic>> register(
      String name, String email, String password, String role) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': role,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? 'Registration failed'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('Attempting login for: $email');
        print('Login URL: ${ApiConstants.baseUrl}/api/login');
      }

      // First get token
      final tokenResponse = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': email,
          'password': password,
        },
      );

      if (kDebugMode) {
        print('Login status code: ${tokenResponse.statusCode}');
        print('Login response body: ${tokenResponse.body}');
      }

      if (tokenResponse.statusCode != 200) {
        final tokenData = jsonDecode(tokenResponse.body);
        return {
          'success': false,
          'message': tokenData['detail'] ?? 'Login failed'
        };
      }

      final tokenData = jsonDecode(tokenResponse.body);
      _token = tokenData['access_token'];

      // Get user data from the /me endpoint
      try {
        final userResponse = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/api/me'),
          headers: {
            'Authorization': 'Bearer $_token',
          },
        );

        if (kDebugMode) {
          print('User info status code: ${userResponse.statusCode}');
          print('User info response body: ${userResponse.body}');
        }

        if (userResponse.statusCode == 200) {
          final userData = jsonDecode(userResponse.body);
          _currentUser = User.fromJson(userData);
          await _saveUserToPrefs();
          return {'success': true};
        } else {
          // Fallback to parsing JWT if /me endpoint fails
          return await _extractUserFromToken(email);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching user info: $e');
        }
        // Fallback to parsing JWT
        return await _extractUserFromToken(email);
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper method to extract user info from JWT token
  Future<Map<String, dynamic>> _extractUserFromToken(String email) async {
    try {
      // Parse JWT to get user data
      final parts = _token!.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final Map<String, dynamic> jwtData = jsonDecode(decoded);

        // Create user from JWT data
        _currentUser = User(
          id: jwtData['user_id'],
          name: email.split('@')[0], // Use part of email as name
          email: jwtData['sub'],
          role: jwtData['role'],
          createdAt: DateTime.now(), // We don't have this from the token
        );
        await _saveUserToPrefs();
        return {'success': true};
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing JWT: $e');
      }
    }

    // If we reach here, something went wrong
    _token = null;
    return {'success': false, 'message': 'Failed to get user data'};
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await _prefs.remove('token');
    await _prefs.remove('user');
    notifyListeners();
  }
}
