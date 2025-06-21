import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logging/logging.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/nlp_service.dart';
import '../services/email_service.dart';
import '../services/google_auth_service.dart';
import '../providers/app_state_provider.dart';
import '../utils/app_logger.dart';
import 'google_sign_in_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  final NLPService _nlpService = NLPService();
  final EmailService _emailService = EmailService();
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final Logger _logger = AppLogger.getLogger('HomeScreen');

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String _statusMessage = "Ready";
  String _transcribedText = "";
  bool _hasWelcomed = false;
  bool _microphonePermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // First check if Gmail API is authenticated
    if (!_googleAuthService.isSignedIn) {
      // If not signed in with Google, redirect to sign-in screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const GoogleSignInScreen(),
          ),
        );
      }
      return;
    }

    // Then check microphone permissions
    await _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    _logger.info('Checking microphone permission status...');
    final status = await Permission.microphone.status;
    _logger.info('Microphone permission status: $status');
    setState(() {
      _microphonePermissionGranted = status.isGranted;
    });

    if (_microphonePermissionGranted) {
      // Try to authenticate with Gmail API
      try {
        await _emailService.authenticate();
        _welcomeUser();
      } catch (e) {
        // If Gmail API authentication fails, inform the user
        await _ttsService.speak(
            "There was an issue connecting to your Gmail account. Some features may not work properly.");
        _welcomeUser();
      }
    } else {
      _requestPermissions();
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _statusMessage = "Requesting microphone permission...";
    });

    _logger.info('Requesting microphone permission...');
    final status = await Permission.microphone.request();
    _logger.info('Microphone permission request result: $status');

    setState(() {
      _microphonePermissionGranted = status.isGranted;
    });

    if (_microphonePermissionGranted) {
      await _ttsService
          .speak("Microphone permission granted. Let's get started!");
      _welcomeUser();
    } else {
      setState(() {
        _statusMessage = "Microphone permission required";
      });
      await _ttsService.speak(
          "Microphone permission is required for voice commands. Please grant permission in settings.");
    }
  }

  Future<void> _welcomeUser() async {
    setState(() {
      _isSpeaking = true;
      _statusMessage = "Welcome message...";
    });

    await Future.delayed(const Duration(milliseconds: 500));

    // Get user name for personalized welcome
    final userName = await _googleAuthService.getUserName();
    final welcomeMessage = userName != null
        ? "Welcome back, $userName! What would you like to do today?"
        : "Welcome to Voice Email Assistant! What would you like to do today?";

    await _ttsService.speak(welcomeMessage);

    setState(() {
      _isSpeaking = false;
      _hasWelcomed = true;
    });

    // Automatically start listening after welcome
    await Future.delayed(const Duration(milliseconds: 500));
    _startListening();
  }

  Future<void> _handleSignOut() async {
    try {
      await _ttsService.speak("Signing out of your Google account.");

      _emailService.signOut();
      await _googleAuthService.signOut();

      await _ttsService.speak(
          "You have been signed out. Taking you back to the sign-in screen.");

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const GoogleSignInScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      await _ttsService
          .speak("There was an error signing out. Please try again.");
    }
  }

  Future<void> _startListening() async {
    if (_isListening || _isSpeaking || !_microphonePermissionGranted) return;

    setState(() {
      _isListening = true;
      _statusMessage = "Listening... Speak now";
      _transcribedText = "";
    });

    try {
      final String transcript = await _sttService.listen();

      setState(() {
        _isListening = false;
        _isProcessing = true;
        _transcribedText = transcript;
        _statusMessage = "Processing your request...";
      });

      if (transcript.isNotEmpty) {
        await _processVoiceCommand(transcript);
      } else {
        await _ttsService.speak("I didn't hear anything. Please try again.");
        setState(() {
          _statusMessage = "Ready - Tap anywhere to speak";
        });
      }
    } catch (e) {
      setState(() {
        _isListening = false;
        _statusMessage = "Ready - Tap anywhere to speak";
      });

      if (e.toString().contains('Speech-to-Text service failed:')) {
        if (e.toString().contains('permission')) {
          await _ttsService.speak(
              "Microphone permission is required. Please grant permission and try again.");
          _checkPermissions();
        } else {
          await _ttsService.speak(
              "There was an issue with the speech recognition service. Please try again.");
        }
      } else {
        await _ttsService
            .speak("Sorry, I couldn't hear you clearly. Please try again.");
      }
    }
  }

  Future<void> _processVoiceCommand(String transcript) async {
    try {
      final commandResult = await _nlpService.processCommand(transcript);

      setState(() {
        _statusMessage = "Command: ${commandResult.action}";
      });

      switch (commandResult.action) {
        case 'send_email':
          await _handleSendEmail(commandResult);
          break;
        case 'read_email':
          await _handleReadEmail();
          break;
        case 'reply_email':
          await _ttsService.speak(
              "Reply feature is coming soon. What else would you like to do?");
          break;
        case 'delete_email':
          await _ttsService.speak(
              "Delete feature is coming soon. What else would you like to do?");
          break;
        case 'forward_email':
          await _ttsService.speak(
              "Forward feature is coming soon. What else would you like to do?");
          break;
        case 'save_contact':
          await _handleSaveContact(commandResult);
          break;
        default:
          await _ttsService.speak(
              "I understand you said: $transcript. However, I'm not sure what action you want me to take. You can say things like 'read my emails', 'send an email', or 'save a contact'. What would you like to do?");
      }
    } catch (e) {
      if (e.toString().contains('Gemini API service failed:')) {
        await _ttsService.speak(
            "There was an issue with the Gemini AI service. I'll try to understand your command using basic processing. Please try again.");
      } else if (e.toString().contains('Gmail API')) {
        await _ttsService.speak(
            "There was an issue with the Gmail service. Please make sure you're logged into Gmail and try again.");
      } else {
        await _ttsService.speak(
            "I had trouble understanding that. Please try saying something like 'read my emails' or 'send an email'. What would you like to do?");
      }
    } finally {
      setState(() {
        _isProcessing = false;
        _statusMessage = "Ready - Tap anywhere to speak";
      });
    }
  }

  Future<void> _handleSendEmail(dynamic commandResult) async {
    try {
      await _ttsService.speak(
          "I understand you want to send an email. This feature is being set up. What else would you like to do?");
    } catch (e) {
      if (e.toString().contains('Gmail API')) {
        await _ttsService
            .speak("There was an issue connecting to Gmail. Please try again.");
      } else {
        await _ttsService.speak(
            "There was an issue with the email feature. What else would you like to do?");
      }
    }
  }

  Future<void> _handleReadEmail() async {
    try {
      final emails = await _emailService.getUnreadEmails();

      if (emails.isEmpty) {
        await _ttsService.speak(
            "You have no unread emails. What else would you like to do?");
      } else {
        await _ttsService.speak(
            "You have ${emails.length} unread emails. Here are the most recent ones:");

        for (int i = 0; i < emails.length && i < 3; i++) {
          final email = emails[i];
          await _ttsService
              .speak("Email ${i + 1} from ${email.sender}: ${email.subject}");
        }

        await _ttsService.speak("What would you like to do next?");
      }
    } catch (e) {
      if (e.toString().contains('Gmail API')) {
        await _ttsService.speak(
            "There was an issue accessing your Gmail account. Please try again.");
      } else {
        await _ttsService.speak(
            "There was an issue reading your emails. Please try again later.");
      }
    }
  }

  Future<void> _handleSaveContact(dynamic commandResult) async {
    try {
      final name = commandResult.name;
      final email = commandResult.email;

      if (name != null && email != null) {
        if (!mounted) return;
        await Provider.of<AppStateProvider>(context, listen: false)
            .saveContact(name, email);
        await _ttsService.speak(
            "Contact $name saved successfully with email $email. What else would you like to do?");
      } else {
        await _ttsService.speak(
            "To save a contact, please say something like 'save John with email john@example.com'. What would you like to do?");
      }
    } catch (e) {
      if (e.toString().contains('Supabase')) {
        await _ttsService.speak(
            "There was an issue with the contact database service. Please try again later.");
      } else {
        await _ttsService.speak(
            "I couldn't save that contact. Please try again or do something else.");
      }
    }
  }

  void _onScreenTap() {
    if (!_microphonePermissionGranted) {
      _requestPermissions();
    } else if (!_isListening &&
        !_isProcessing &&
        !_isSpeaking &&
        _hasWelcomed) {
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Voice Email Assistant'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(_googleAuthService.isSignedIn
                ? Icons.account_circle
                : Icons.account_circle_outlined),
            onSelected: (value) async {
              if (value == 'sign_out') {
                await _handleSignOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'sign_out',
                child: Row(
                  children: [
                    const Icon(Icons.logout),
                    const SizedBox(width: 8),
                    Text(
                        _googleAuthService.isSignedIn ? 'Sign Out' : 'Sign In'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _onScreenTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !_microphonePermissionGranted
                        ? Colors.red
                        : _isListening
                            ? Colors.red
                            : _isProcessing
                                ? Colors.orange
                                : _isSpeaking
                                    ? Colors.blue
                                    : Colors.green,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _statusMessage,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Permission and Gmail status indicators
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _microphonePermissionGranted
                              ? Icons.check_circle
                              : Icons.error_outline,
                          color: _microphonePermissionGranted
                              ? Colors.green
                              : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _microphonePermissionGranted
                              ? 'Microphone Enabled'
                              : 'Microphone Permission Required',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _googleAuthService.isSignedIn
                              ? Icons.check_circle
                              : Icons.error_outline,
                          color: _googleAuthService.isSignedIn
                              ? Colors.green
                              : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _googleAuthService.isSignedIn
                              ? 'Google Account Connected'
                              : 'Google Account Not Connected',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                if (_transcribedText.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'You said: "$_transcribedText"',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 40),
                // Large microphone icon
                Icon(
                  _isListening
                      ? Icons.mic
                      : !_microphonePermissionGranted
                          ? Icons.mic_off
                          : Icons.mic_none,
                  size: 100,
                  color: !_microphonePermissionGranted
                      ? Colors.red
                      : _isListening
                          ? Colors.red
                          : Colors.blue,
                ),
                const SizedBox(height: 20),
                Text(
                  !_microphonePermissionGranted
                      ? 'Tap to grant microphone permission'
                      : _isListening
                          ? 'Listening...'
                          : _isProcessing
                              ? 'Processing...'
                              : _isSpeaking
                                  ? 'Speaking...'
                                  : _hasWelcomed
                                      ? 'Tap anywhere to speak'
                                      : 'Initializing...',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (_hasWelcomed &&
                    !_isListening &&
                    !_isProcessing &&
                    !_isSpeaking &&
                    _microphonePermissionGranted)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Try saying:\n• "Read my emails"\n• "Send an email"\n• "Save contact John with email john@example.com"',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
