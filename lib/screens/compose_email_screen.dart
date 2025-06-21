import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/email_service.dart';
import '../providers/app_state_provider.dart';
import 'package:provider/provider.dart';

class ComposeEmailScreen extends StatefulWidget {
  final String? initialRecipient;
  final String? initialSubject;
  final String? initialBody;
  final bool isReply;

  const ComposeEmailScreen({
    super.key,
    this.initialRecipient,
    this.initialSubject,
    this.initialBody,
    this.isReply = false,
  });

  @override
  ComposeEmailScreenState createState() => ComposeEmailScreenState();
}

class ComposeEmailScreenState extends State<ComposeEmailScreen> {
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  final EmailService _emailService = EmailService();

  String _recipient = '';
  String _subject = '';
  String _body = '';

  bool _isListening = false;
  bool _isSending = false;
  String _currentField = '';

  @override
  void initState() {
    super.initState();
    _recipient = widget.initialRecipient ?? '';
    _subject = widget.initialSubject ?? '';
    _body = widget.initialBody ?? '';

    _startComposition();
  }

  Future<void> _startComposition() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (widget.isReply) {
      await _ttsService.speak(
          "Composing a reply to ${widget.initialRecipient}. The subject is ${widget.initialSubject}. "
          "Please say your message.");
      _currentField = 'body';
    } else {
      await _ttsService.speak(
          "Composing a new email. Who would you like to send this email to?");
      _currentField = 'recipient';
    }
  }

  Future<void> _listenForInput() async {
    if (_isListening) return;

    setState(() {
      _isListening = true;
    });

    try {
      final String transcript = await _sttService.listen();

      setState(() {
        _isListening = false;
      });

      await _processInput(transcript);
    } catch (e) {
      setState(() {
        _isListening = false;
      });

      await _ttsService.speak("Sorry, I couldn't hear you. Please try again.");
    }
  }

  Future<void> _processInput(String transcript) async {
    if (transcript.toLowerCase().contains('cancel') ||
        transcript.toLowerCase().contains('go back')) {
      await _ttsService.speak("Cancelling email composition.");
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    switch (_currentField) {
      case 'recipient':
        setState(() {
          _recipient = transcript;
        });

        // Try to find contact by name
        if (!mounted) return;
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        final contact = await appState.findContactByName(transcript);

        if (contact != null) {
          setState(() {
            _recipient = contact.email;
          });

          await _ttsService.speak(
              "Found contact ${contact.name} with email ${contact.email}. What is the subject of your email?");
        } else {
          await _ttsService.speak(
              "Recipient set to $transcript. What is the subject of your email?");
        }

        _currentField = 'subject';
        break;

      case 'subject':
        setState(() {
          _subject = transcript;
        });

        await _ttsService.speak(
            "Subject set to $transcript. What is the message of your email?");

        _currentField = 'body';
        break;

      case 'body':
        setState(() {
          _body = transcript;
        });

        await _ttsService.speak(
            "Your email to $_recipient with subject $_subject says: $transcript. "
            "Would you like to send it, edit it, or cancel?");

        _currentField = 'confirmation';
        break;

      case 'confirmation':
        if (transcript.toLowerCase().contains('send')) {
          await _sendEmail();
        } else if (transcript.toLowerCase().contains('edit')) {
          await _ttsService.speak(
              "What would you like to edit? You can say recipient, subject, or message.");

          _currentField = 'edit_choice';
        } else if (transcript.toLowerCase().contains('cancel')) {
          await _ttsService.speak("Cancelling email composition.");
          if (!mounted) return;
          Navigator.of(context).pop();
        } else {
          await _ttsService.speak(
              "I didn't understand. Would you like to send the email, edit it, or cancel?");
        }
        break;

      case 'edit_choice':
        if (transcript.toLowerCase().contains('recipient')) {
          await _ttsService.speak(
              "Current recipient is $_recipient. Who would you like to send this email to instead?");

          _currentField = 'recipient';
        } else if (transcript.toLowerCase().contains('subject')) {
          await _ttsService.speak(
              "Current subject is $_subject. What would you like to change it to?");

          _currentField = 'subject';
        } else if (transcript.toLowerCase().contains('message') ||
            transcript.toLowerCase().contains('body')) {
          await _ttsService.speak(
              "Current message is $_body. What would you like to change it to?");

          _currentField = 'body';
        } else {
          await _ttsService.speak(
              "I didn't understand. What would you like to edit? You can say recipient, subject, or message.");
        }
        break;
    }
  }

  Future<void> _sendEmail() async {
    setState(() {
      _isSending = true;
    });

    try {
      await _emailService.sendEmail(_recipient, _subject, _body);

      await _ttsService.speak("Email sent successfully.");

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isSending = false;
      });

      await _ttsService.speak("Failed to send email. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isReply ? 'Reply to Email' : 'Compose Email'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: TextEditingController(text: _recipient),
              decoration: const InputDecoration(
                labelText: 'To',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: () {
                _currentField = 'recipient';
                _listenForInput();
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: TextEditingController(text: _subject),
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: () {
                _currentField = 'subject';
                _listenForInput();
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: _body),
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                readOnly: true,
                onTap: () {
                  _currentField = 'body';
                  _listenForInput();
                },
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _isListening || _isSending ? null : _listenForInput,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? Colors.red
                        : (_isSending ? Colors.grey : Colors.blue),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isListening
                          ? Icons.mic
                          : (_isSending ? Icons.send : Icons.mic_none),
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _isListening
                    ? 'Listening...'
                    : (_isSending ? 'Sending...' : 'Tap to speak'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
