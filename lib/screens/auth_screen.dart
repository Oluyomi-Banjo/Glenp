import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/tts_service.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final TTSService _ttsService = TTSService();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _startAuthentication();
  }

  Future<void> _startAuthentication() async {
    // Announce the authentication process
    await _ttsService.speak("Please authenticate using your fingerprint or face ID.");
    
    setState(() {
      _isAuthenticating = true;
    });
    
    try {
      final bool success = await _authService.authenticate();
      
      if (success) {
        await _ttsService.speak("Authentication successful.");
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        }
      } else {
        await _ttsService.speak("Authentication failed. Please try again.");
        setState(() {
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      await _ttsService.speak("Authentication error. Please try again later.");
      setState(() {
        _isAuthenticating = false;
      });
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
              Icons.fingerprint,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 30),
            Text(
              'Biometric Authentication',
              style: Theme.of(context).textTheme.headlineSmall,
              semanticsLabel: 'Biometric Authentication Required',
            ),
            const SizedBox(height: 20),
            Text(
              'Please authenticate to access your emails',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (!_isAuthenticating)
              ElevatedButton(
                onPressed: _startAuthentication,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text('Authenticate'),
              ),
          ],
        ),
      ),
    );
  }
}
