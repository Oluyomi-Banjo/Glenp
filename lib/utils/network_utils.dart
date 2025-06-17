import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkUtils {
  // Check if device is connected to a network
  static Future<bool> hasNetwork() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
  
  // Check if connected to the Raspberry Pi network
  static Future<bool> isOnLocalNetwork() async {
    try {
      // This is a simple check that tries to reach the Pi's server
      // In a real implementation, you might need a more sophisticated check
      final response = await http.get(
        Uri.parse('http://192.168.4.1:8000/'),
        headers: {'Connection': 'keep-alive'},
      ).timeout(const Duration(seconds: 2));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  // Helper to make authenticated GET requests
  static Future<http.Response> authenticatedGet(String url, String token) async {
    return await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }
  
  // Helper to make authenticated POST requests
  static Future<http.Response> authenticatedPost(String url, String token, dynamic body) async {
    return await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }
  
  // Helper to make authenticated PATCH requests
  static Future<http.Response> authenticatedPatch(String url, String token, dynamic body) async {
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
