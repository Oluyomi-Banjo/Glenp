import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import '../utils/app_logger.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  final Logger _logger = AppLogger.getLogger('GoogleAuthService');
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  bool _isInitialized = false;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      final clientId = dotenv.env['GMAIL_CLIENT_ID'] ?? '';
      
      if (clientId.isEmpty || clientId == 'placeholder-client-id') {
        throw Exception('Google Sign-In not configured: Gmail Client ID missing');
      }

      _googleSignIn = GoogleSignIn(
        clientId: clientId,
        scopes: [
          'email',
          'profile',
          'https://www.googleapis.com/auth/gmail.send',
          'https://www.googleapis.com/auth/gmail.readonly',
        ],
      );

      // Check if user was previously signed in
      await _checkPreviousSignIn();
      
      _isInitialized = true;
      _logger.info("Google Sign-In service initialized");
    } catch (e) {
      _logger.severe("Google Sign-In initialization error: $e");
      throw Exception('Google Sign-In service failed to initialize: $e');
    }
  }

  Future<void> _checkPreviousSignIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasSignedIn = prefs.getBool('google_signed_in') ?? false;
      
      if (wasSignedIn) {
        _currentUser = await _googleSignIn?.signInSilently();
        if (_currentUser != null) {
          _logger.info("User automatically signed in: ${_currentUser!.email}");
        } else {
          // Clear the flag if silent sign-in failed
          await prefs.setBool('google_signed_in', false);
        }
      }
    } catch (e) {
      _logger.warning("Error checking previous sign-in: $e");
      // Clear the flag on error
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('google_signed_in', false);
    }
  }

  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('google_signed_in') ?? false);
  }

  Future<GoogleSignInAccount> signIn() async {
    await _initialize();
    
    if (_googleSignIn == null) {
      throw Exception('Google Sign-In service not initialized');
    }

    try {
      _logger.info("Starting Google Sign-In process...");
      
      // Sign out first to ensure clean sign-in
      await _googleSignIn!.signOut();
      
      final GoogleSignInAccount? account = await _googleSignIn!.signIn();
      
      if (account == null) {
        throw Exception('Google Sign-In was cancelled by user');
      }

      _currentUser = account;
      
      // Save sign-in status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('google_signed_in', true);
      await prefs.setString('user_email', account.email);
      await prefs.setString('user_name', account.displayName ?? '');
      
      // Mark sign-in as completed (for first-time users)
      await prefs.setBool('has_completed_signin', true);
      
      _logger.info("Google Sign-In successful: ${account.email}");
      return account;
    } catch (e) {
      _logger.severe("Google Sign-In error: $e");
      throw Exception('Google Sign-In failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
      _currentUser = null;
      
      // Clear sign-in status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('google_signed_in', false);
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      
      _logger.info("Google Sign-Out successful");
    } catch (e) {
      _logger.warning("Google Sign-Out error: $e");
      throw Exception('Google Sign-Out failed: $e');
    }
  }

  Future<String?> getUserEmail() async {
    if (_currentUser != null) {
      return _currentUser!.email;
    }
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  Future<String?> getUserName() async {
    if (_currentUser != null) {
      return _currentUser!.displayName;
    }
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  Future<Map<String, String>> getAuthHeaders() async {
    await _initialize();
    
    if (_currentUser == null) {
      throw Exception('User not signed in');
    }

    try {
      final GoogleSignInAuthentication auth = await _currentUser!.authentication;
      
      return {
        'Authorization': 'Bearer ${auth.accessToken}',
        'Content-Type': 'application/json',
      };
    } catch (e) {
      _logger.severe("Error getting auth headers: $e");
      throw Exception('Failed to get authentication headers: $e');
    }
  }
}
