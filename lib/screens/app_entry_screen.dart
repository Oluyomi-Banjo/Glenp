import 'package:flutter/material.dart';
import '../services/google_auth_service.dart';
import '../services/tts_service.dart';
import 'google_sign_in_screen.dart';
import 'home_screen.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  AppEntryScreenState createState() => AppEntryScreenState();
}

class AppEntryScreenState extends State<AppEntryScreen> {
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final TTSService _ttsService = TTSService();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Initialize TTS service
      await _ttsService.initTTS();

      // Check if user is already signed in
      if (_googleAuthService.isSignedIn) {
        // User is already signed in, go directly to home screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        }
      } else {
        // User is not signed in, go to Google sign-in screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const GoogleSignInScreen(),
            ),
          );
        }
      }
    } catch (e) {
      // On error, show sign-in screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const GoogleSignInScreen(),
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
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Loading...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
