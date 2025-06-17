import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:attendance_app/utils/constants.dart';

class NetworkUtils {
  // Check if device is connected to a network
  static Future<bool> hasNetwork() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Check if connected to the Raspberry Pi network
  static Future<bool> isOnLocalNetwork() async {
    try {
      // First check if we have any network connection
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (kDebugMode) {
          print('No network connectivity detected');
        }
        return false;
      }

      // Try to reach the Raspap server using an endpoint we know exists
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/ping'),
        headers: {'Connection': 'keep-alive'},
      ).timeout(const Duration(seconds: 3));

      if (kDebugMode) {
        print(
            'Network check result: ${response.statusCode} - ${response.body}');
      }

      // If ping endpoint fails, try just reaching the base URL
      if (response.statusCode == 404) {
        try {
          final baseResponse = await http.head(
            Uri.parse(ApiConstants.baseUrl),
            headers: {'Connection': 'keep-alive'},
          ).timeout(const Duration(seconds: 2));

          if (kDebugMode) {
            print('Base URL check: ${baseResponse.statusCode}');
          }

          return baseResponse.statusCode <
              500; // Any non-server error means we can reach the server
        } catch (e) {
          if (kDebugMode) {
            print('Base URL check error: $e');
          }
          // If we can connect to login, that's good enough
          try {
            final loginUrlTest = await http.head(
              Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
              headers: {'Connection': 'keep-alive'},
            ).timeout(const Duration(seconds: 2));

            return loginUrlTest.statusCode < 500;
          } catch (e) {
            if (kDebugMode) {
              print('Login URL check error: $e');
            }
            return false;
          }
        }
      }

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      if (kDebugMode) {
        print('Network check error: $e');
      }
      return false;
    }
  }

  // Helper to make authenticated GET requests
  static Future<http.Response> authenticatedGet(
      String url, String token) async {
    if (kDebugMode) {
      print('Making GET request to: $url');
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode && response.statusCode != 200) {
        print('Request failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Network error in GET request: $e');
      }
      rethrow;
    }
  }

  // Helper to make authenticated POST requests
  static Future<http.Response> authenticatedPost(
      String url, String token, dynamic body) async {
    if (kDebugMode) {
      print('Making POST request to: $url');
      print('Request body: $body');
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (kDebugMode &&
          (response.statusCode < 200 || response.statusCode >= 300)) {
        print('Request failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Network error in POST request: $e');
      }
      rethrow;
    }
  }

  // Helper to make authenticated PATCH requests
  static Future<http.Response> authenticatedPatch(
      String url, String token, dynamic body) async {
    return await http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }
}
