import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_auth_service.dart';

class AuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  bool _isInitialized = false;

  AuthService();

  Future<void> _initializeSupabase() async {
    if (!_isInitialized) {
      try {
        final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
        final supabaseKey = dotenv.env['SUPABASE_KEY'] ?? '';

        // Check if Supabase is already initialized by trying to access it
        try {
          Supabase.instance.client.auth.currentSession;
          _isInitialized = true;
          return;
        } catch (e) {
          // Supabase not initialized yet, continue with initialization
        }

        if (supabaseUrl.isNotEmpty &&
            supabaseKey.isNotEmpty &&
            supabaseUrl != 'https://placeholder.supabase.co' &&
            supabaseKey != 'placeholder-key') {
          await Supabase.initialize(
            url: supabaseUrl,
            anonKey: supabaseKey,
          );
        }

        _isInitialized = true;
      } catch (e) {
        _isInitialized = true; // Set to true to avoid retrying
      }
    }
  }

  Future<bool> isAuthenticated() async {
    await _initializeSupabase();
    
    // Check if user has completed Google sign-in previously
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedSignIn = prefs.getBool('has_completed_signin') ?? false;
    
    // If user has completed sign-in before, check if Google auth is still valid
    if (hasCompletedSignIn) {
      return _googleAuthService.isSignedIn;
    }
    
    return false;
  }

  Future<bool> authenticate() async {
    try {
      final bool canAuthenticate = await _localAuth.canCheckBiometrics;

      if (!canAuthenticate) {
        return true; // Allow access for devices without biometrics
      }

      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      if (availableBiometrics.isEmpty) {
        return true; // Allow access for devices without biometrics
      }

      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access your emails',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/password as fallback
        ),
      );
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable) {
        // Biometrics not available on this device
        return true; // Allow access for devices without biometrics
      }
      return true; // Allow access on authentication errors for testing
    } catch (e) {
      return true; // Allow access on errors for testing
    }
  }

  Future<void> markSignInCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_signin', true);
  }

  Future<bool> isFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('has_completed_signin') ?? false);
  }

  Future<void> signOut() async {
    await _initializeSupabase();
    try {
      await Supabase.instance.client.auth.signOut();
      await _googleAuthService.signOut();
      
      // Clear first-time user flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_signin', false);
    } catch (e) {
      // Ignore errors when signing out
    }
  }
}
