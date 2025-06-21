import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/nlp_service.dart';
import '../services/google_auth_service.dart';
import 'google_sign_in_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceHomeScreen extends StatefulWidget {
  const VoiceHomeScreen({super.key});

  @override
  VoiceHomeScreenState createState() => VoiceHomeScreenState();
}

class VoiceHomeScreenState extends State<VoiceHomeScreen> {
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  final NLPService _nlpService = NLPService();
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String _transcribedText = "";
  String _responseText = "";
  bool _hasWelcomed = false;

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

    // Initialize services
    await _requestPermissions();
    await _ttsService.initTTS();

    // Welcome the user
    if (!_hasWelcomed && mounted) {
      setState(() {
        _hasWelcomed = true;
        _isSpeaking = true;
      });

      // Get user's name if available
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_name') ?? 'there';

      await _ttsService.speak(
          "Welcome back, $userName. Tap anywhere on the screen to start or stop speaking.");

      setState(() {
        _isSpeaking = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    final microphoneStatus = await Permission.microphone.request();
    if (microphoneStatus.isDenied || microphoneStatus.isPermanentlyDenied) {
      if (mounted) {
        await _ttsService.speak(
            "Microphone permission is required for voice recognition. Please enable it in settings.");

        if (microphoneStatus.isPermanentlyDenied) {
          // Show dialog to open app settings
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Microphone Permission Required'),
                  content: const Text(
                      'Voice commands require microphone access. Please enable it in app settings.'),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Open Settings'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        openAppSettings();
                      },
                    ),
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          }
        }
      }
    }
  }

  void _toggleListening() async {
    if (_isProcessing || _isSpeaking) {
      // Don't start listening if we're already processing or speaking
      return;
    }

    setState(() {
      _isListening = !_isListening;
    });

    if (_isListening) {
      // Start listening      _transcribedText = "";
      setState(() {});

      final bool success = await _sttService.startListening(
        onResult: (text) {
          setState(() {
            _transcribedText = text;
          });
        },
        onError: (error) async {
          setState(() {
            _isListening = false;
          });
          await _ttsService.speak("I couldn't hear you. Please try again.");
        },
      );

      if (!success) {
        setState(() {
          _isListening = false;
        });
        await _ttsService.speak(
            "Speech recognition couldn't start. Please check your microphone permissions.");
      }
    } else {
      // Stop listening and process the command
      await _sttService.stopListening();

      if (_transcribedText.isNotEmpty) {
        _processCommand(_transcribedText);
      }
    }
  }

  Future<void> _processCommand(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _responseText = "Processing...";
    });

    try {
      // Process with NLP service
      final result = await _nlpService.processCommand(text);

      // Generate response based on the command
      String response;

      switch (result.action) {
        case 'send_email':
          response = "I'll send an email";
          if (result.recipient != null) {
            response += " to ${result.recipient}";
          }
          if (result.subject != null) {
            response += " with subject: ${result.subject}";
          }

          // Here you would actually send the email using EmailService
          // await _emailService.sendEmail(result.recipient, result.subject, result.body);

          break;

        case 'read_emails':
          response = "I'll read your emails";
          // Here you would fetch and read emails
          // final emails = await _emailService.fetchEmails();
          break;

        case 'add_contact':
          response = "I'll add a new contact";
          if (result.name != null) {
            response += " named ${result.name}";
          }
          if (result.email != null) {
            response += " with email ${result.email}";
          }
          break;

        default:
          response =
              "I heard you say: $text. How can I help you with your emails?";
      }

      setState(() {
        _responseText = response;
        _isProcessing = false;
        _isSpeaking = true;
      });

      // Speak the response
      await _ttsService.speak(response);

      setState(() {
        _isSpeaking = false;
      });
    } catch (e) {
      setState(() {
        _responseText =
            "Sorry, I encountered an error processing your request.";
        _isProcessing = false;
        _isSpeaking = true;
      });

      await _ttsService
          .speak("Sorry, I encountered an error processing your request.");

      setState(() {
        _isSpeaking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleListening,
      child: Scaffold(
        body: SafeArea(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: _getBackgroundColor(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 1),

                // Status icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      _getStatusIcon(),
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Status text
                Text(
                  _getStatusText(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Transcription or response
                if (_transcribedText.isNotEmpty || _responseText.isNotEmpty)
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _isListening ? _transcribedText : _responseText,
                          style: TextStyle(
                            fontSize: 18,
                            color: _isListening ? Colors.black87 : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),

                const Spacer(flex: 1),

                // Helper text
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    "Tap anywhere on the screen to start or stop listening",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (_isListening) {
      return Colors.red.withAlpha(25);
    } else if (_isProcessing) {
      return Colors.orange.withAlpha(25);
    } else if (_isSpeaking) {
      return Colors.green.withAlpha(25);
    }
    return Colors.blue.withAlpha(13);
  }

  Color _getStatusColor() {
    if (_isListening) {
      return Colors.red;
    } else if (_isProcessing) {
      return Colors.orange;
    } else if (_isSpeaking) {
      return Colors.green;
    }
    return Colors.blue;
  }

  IconData _getStatusIcon() {
    if (_isListening) {
      return Icons.mic;
    } else if (_isProcessing) {
      return Icons.hourglass_top;
    } else if (_isSpeaking) {
      return Icons.volume_up;
    }
    return Icons.touch_app;
  }

  String _getStatusText() {
    if (_isListening) {
      return "Listening...";
    } else if (_isProcessing) {
      return "Processing...";
    } else if (_isSpeaking) {
      return "Speaking...";
    }
    return "Tap to speak";
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }
}

// Remove unused fields and fix any remaining issues
