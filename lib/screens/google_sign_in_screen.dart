import 'package:flutter/material.dart';
import '../services/google_auth_service.dart';
import '../services/auth_service.dart';
import '../services/tts_service.dart';
import 'voice_home_screen.dart';

class GoogleSignInScreen extends StatefulWidget {
  const GoogleSignInScreen({super.key});

  @override
  GoogleSignInScreenState createState() => GoogleSignInScreenState();
}

class GoogleSignInScreenState extends State<GoogleSignInScreen> {
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final TTSService _ttsService = TTSService();
  bool _isSigningIn = false;
  String _statusMessage = "Welcome to Voice Email Assistant";

  @override
  void initState() {
    super.initState();
    _initializeAndWelcome();
  }

  Future<void> _initializeAndWelcome() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _ttsService.initTTS();
    await _ttsService.speak(
        "Welcome to Voice Email Assistant. To get started, you need to sign in with your Google account. "
        "Please ask someone to help you tap the 'Sign in with Google' button and complete the sign-in process.");
  }

  Future<void> _handleSignIn() async {
    if (_isSigningIn) return;

    setState(() {
      _isSigningIn = true;
      _statusMessage = "Signing in with Google...";
    });

    try {
      await _ttsService.speak(
          "Starting Google sign-in process. Please follow the instructions on screen.");

      final account = await _googleAuthService.signIn();
      
      // Mark sign-in as completed
      final authService = AuthService();
      await authService.markSignInCompleted();

      await _ttsService.speak(
          "Sign-in successful! Welcome ${account.displayName ?? 'User'}. "
          "You are now signed in with ${account.email}. "
          "Taking you to the main app.");

      // Navigate directly to home screen after successful sign-in
      if (mounted) {          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const VoiceHomeScreen(),
            ),
          );
      }
    } catch (e) {
      setState(() {
        _isSigningIn = false;
        _statusMessage = "Sign-in failed. Please try again.";
      });

      if (e.toString().contains('cancelled by user')) {
        await _ttsService.speak(
            "Sign-in was cancelled. Please try again when you're ready to sign in with Google.");
      } else if (e.toString().contains('not configured')) {
        await _ttsService.speak(
            "Google sign-in is not properly configured. Please contact support.");
      } else {
        await _ttsService.speak(
            "Sign-in failed. Please check your internet connection and try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon and title
              const Icon(
                Icons.email,
                size: 120,
                color: Colors.blue,
              ),
              const SizedBox(height: 30),
              Text(
                'Voice Email Assistant',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
                semanticsLabel: 'Voice Email Assistant',
              ),
              const SizedBox(height: 20),
              Text(
                'For Visually Impaired Users',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),

              // Status message
              Text(
                _statusMessage,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
                semanticsLabel: _statusMessage,
              ),
              const SizedBox(height: 40),

              // Sign-in button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _isSigningIn ? null : _handleSignIn,
                  icon: _isSigningIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.login, size: 24),
                  label: Text(
                    _isSigningIn ? 'Signing in...' : 'Sign in with Google',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Help text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Need Help?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ask someone to help you tap the "Sign in with Google" button above. '
                      'You\'ll need to sign in with your Google account to access your emails.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
