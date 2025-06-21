import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/auth_service.dart';
import '../services/tts_service.dart';
import '../services/google_auth_service.dart';
import 'google_sign_in_screen.dart';
import 'voice_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  final TTSService _ttsService = TTSService();
  final AuthService _authService = AuthService();
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize TTS
      await _ttsService.initTTS();
      
      // Delay for splash screen visibility
      await Future.delayed(const Duration(seconds: 2));
      
      // Authenticate with biometrics
      final authenticated = await _authService.authenticate();
      
      if (!authenticated) {
        // Authentication failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Authentication failed. Please try again.'),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _initialize,
              ),
            ),
          );
        }
        return;
      }
      
      // Check if first time user
      final isFirstTimeUser = await _authService.isFirstTimeUser();
      
      if (mounted) {
        if (isFirstTimeUser) {
          // First time user - navigate to Google Sign-in
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const GoogleSignInScreen(),
            ),
          );
        } else {
          // Check if still signed in with Google
          if (_googleAuthService.isSignedIn) {
            // Already signed in - go to home screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const VoiceHomeScreen(),
              ),
            );
          } else {
            // Need to sign in again
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const GoogleSignInScreen(),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Handle errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _initialize,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.email,
              size: 120,
              color: Colors.blue,
            ),
            const SizedBox(height: 30),
            Text(
              'Voice Email Assistant',
              style: Theme.of(context).textTheme.headlineSmall,
              semanticsLabel: 'Voice Email Assistant App',
            ),
            const SizedBox(height: 30),
            const SpinKitDoubleBounce(
              color: Colors.blue,
              size: 50.0,
            ),
          ],
        ),
      ),
    );
  }
}
