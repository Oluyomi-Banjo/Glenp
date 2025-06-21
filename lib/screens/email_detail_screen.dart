import 'package:flutter/material.dart';
import '../models/email_model.dart' as models;
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/nlp_service.dart';
import '../services/email_service.dart';

class EmailDetailScreen extends StatefulWidget {
  final models.Email email;

  const EmailDetailScreen({
    super.key,
    required this.email,
  });

  @override
  EmailDetailScreenState createState() => EmailDetailScreenState();
}

class EmailDetailScreenState extends State<EmailDetailScreen> {
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();
  final NLPService _nlpService = NLPService();
  final EmailService _emailService = EmailService();
  bool _isReading = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _readEmailContent();
  }

  Future<void> _readEmailContent() async {
    setState(() {
      _isReading = true;
    });

    await _ttsService.speak(
      "Email from ${widget.email.sender}. Subject: ${widget.email.subject}. Message: ${widget.email.body}. "
      "What would you like to do? You can say reply, forward, delete, or go back."
    );

    setState(() {
      _isReading = false;
    });
  }

  Future<void> _listenForCommand() async {
    if (_isListening) return;

    setState(() {
      _isListening = true;
    });

    try {
      final String transcript = await _sttService.listen();
      
      setState(() {
        _isListening = false;
      });
      
      await _processCommand(transcript);
    } catch (e) {
      setState(() {
        _isListening = false;
      });
      
      await _ttsService.speak("Sorry, I couldn't hear you. Please try again.");
    }
  }

  Future<void> _processCommand(String transcript) async {
    try {
      final commandResult = await _nlpService.processCommand(transcript);
      
      switch (commandResult.action) {
        case 'reply_email':
          await _handleReply();
          break;
        case 'forward_email':
          await _handleForward();
          break;
        case 'delete_email':
          await _handleDelete();
          break;
        case 'go_back':
          if (!mounted) return;
          Navigator.of(context).pop();
          break;
        default:
          await _ttsService.speak(
            "I didn't understand that. You can say reply, forward, delete, or go back."
          );
      }
    } catch (e) {
      await _ttsService.speak("Sorry, I couldn't process your request. Please try again.");
    }
  }

  Future<void> _handleReply() async {
    await _ttsService.speak("What would you like to say in your reply?");
    
    final String replyContent = await _sttService.listen();
    
    await _ttsService.speak(
      "Your reply says: $replyContent. Should I send it?"
    );
    
    final String confirmation = await _sttService.listen();
    final bool isConfirmed = await _nlpService.isConfirmation(confirmation);
    
    if (isConfirmed) {
      try {
        await _emailService.replyToEmail(widget.email.id, replyContent);
        await _ttsService.speak("Reply sent successfully.");
      } catch (e) {
        await _ttsService.speak("Failed to send reply. Please try again.");
      }
    } else {
      await _ttsService.speak("Reply not sent.");
    }
  }

  Future<void> _handleForward() async {
    await _ttsService.speak("Who would you like to forward this email to?");
    
    final String recipient = await _sttService.listen();
    
    await _ttsService.speak("Would you like to add a comment to the forwarded email?");
    
    final String shouldAddComment = await _sttService.listen();
    final bool addComment = await _nlpService.isConfirmation(shouldAddComment);
    
    String comment = "";
    
    if (addComment) {
      await _ttsService.speak("Please say your comment.");
      comment = await _sttService.listen();
    }
    
    await _ttsService.speak(
      "I'll forward this email to $recipient${addComment ? ' with your comment' : ''}. Should I proceed?"
    );
    
    final String confirmation = await _sttService.listen();
    final bool isConfirmed = await _nlpService.isConfirmation(confirmation);
    
    if (isConfirmed) {
      try {
        await _emailService.forwardEmail(widget.email.id, recipient, comment);
        await _ttsService.speak("Email forwarded successfully.");
      } catch (e) {
        await _ttsService.speak("Failed to forward email. Please try again.");
      }
    } else {
      await _ttsService.speak("Email not forwarded.");
    }
  }

  Future<void> _handleDelete() async {
    await _ttsService.speak(
      "Are you sure you want to delete this email from ${widget.email.sender} with subject ${widget.email.subject}?"
    );
    
    final String confirmation = await _sttService.listen();
    final bool isConfirmed = await _nlpService.isConfirmation(confirmation);
    
    if (isConfirmed) {
      try {
        await _emailService.deleteEmail(widget.email.id);
        await _ttsService.speak("Email deleted successfully.");
        if (!mounted) return;
        Navigator.of(context).pop();
      } catch (e) {
        await _ttsService.speak("Failed to delete email. Please try again.");
      }
    } else {
      await _ttsService.speak("Email not deleted.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Detail'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'From: ${widget.email.sender}',
              style: Theme.of(context).textTheme.titleMedium,
              semanticsLabel: 'From: ${widget.email.sender}',
            ),
            const SizedBox(height: 8),
            Text(
              'Subject: ${widget.email.subject}',
              style: Theme.of(context).textTheme.titleLarge,
              semanticsLabel: 'Subject: ${widget.email.subject}',
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${widget.email.date.toString().substring(0, 16)}',
              style: Theme.of(context).textTheme.bodySmall,
              semanticsLabel: 'Date: ${widget.email.date.toString().substring(0, 16)}',
            ),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  widget.email.body,
                  style: Theme.of(context).textTheme.bodyLarge,
                  semanticsLabel: 'Email body: ${widget.email.body}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _isReading ? null : _listenForCommand,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.red : Colors.blue,
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
                      _isListening ? Icons.mic : Icons.mic_none,
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
                _isListening ? 'Listening...' : 'Tap to speak',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
