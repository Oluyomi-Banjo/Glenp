import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import '../utils/app_logger.dart';

class CommandResult {
  final String action;
  final String? recipient;
  final String? subject;
  final String? body;
  final String? name;
  final String? email;
  final String? messageId;

  CommandResult({
    required this.action,
    this.recipient,
    this.subject,
    this.body,
    this.name,
    this.email,
    this.messageId,
  });

  factory CommandResult.fromJson(Map<String, dynamic> json) {
    return CommandResult(
      action: json['action'] ?? '',
      recipient: json['recipient'],
      subject: json['subject'],
      body: json['body'],
      name: json['name'],
      email: json['email'],
      messageId: json['message_id'],
    );
  }
}

class NLPService {
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  final String _apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';
  final Logger _logger = AppLogger.getLogger('NLPService');

  Future<CommandResult> processCommand(String transcript) async {
    if (_apiKey.isEmpty || _apiKey == 'placeholder-key') {
      _logger.warning("Gemini API key not configured, falling back to simple parsing");
      return _fallbackProcessCommand(transcript);
    }

    try {
      _logger.info("Processing command with Gemini API: $transcript");
      
      final prompt = '''
      Parse the following voice command into structured data for an email assistant app:
      
      "$transcript"
      
      Extract the following information and return ONLY a valid JSON object:
      {
        "action": "One of [send_email, read_email, reply_email, delete_email, forward_email, save_contact]",
        "recipient": "Email recipient's name or email (if applicable)",
        "subject": "Email subject (if applicable)",
        "body": "Email body content (if applicable)",
        "name": "Contact name (for save_contact action)",
        "email": "Contact email (for save_contact action)"
      }
      
      Only include fields that are relevant to the detected action.
      ''';

      final response = await http.post(
        Uri.parse('$_apiEndpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'topP': 0.8,
            'topK': 40
          }
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final textContent = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        
        // Extract JSON from the response
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(textContent);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0);
          final parsedJson = jsonDecode(jsonStr!);
          _logger.info("Gemini API response parsed successfully");
          return CommandResult.fromJson(parsedJson);
        }
        
        throw Exception('Gemini API returned invalid JSON format');
      } else {
        throw Exception('Gemini API request failed with status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _logger.severe("Gemini API error", e, stackTrace);
      throw Exception('Gemini API service failed: $e');
    }
  }

  CommandResult _fallbackProcessCommand(String transcript) {
    final lowerTranscript = transcript.toLowerCase().trim();
    
    String action = '';
    String? recipient;
    String? subject;
    String? body;
    String? name;
    String? email;
    
    if (lowerTranscript.contains('send') || lowerTranscript.contains('compose')) {
      action = 'send_email';
      
      final toMatch = RegExp(r'(?:to|email)\s+([a-zA-Z\s]+)', caseSensitive: false).firstMatch(transcript);
      if (toMatch != null) {
        recipient = toMatch.group(1)?.trim();
      }
      
      final subjectMatch = RegExp(r'(?:about|subject)\s+(.+)', caseSensitive: false).firstMatch(transcript);
      if (subjectMatch != null) {
        subject = subjectMatch.group(1)?.trim();
      }
      
      if (recipient == null && subject == null) {
        body = transcript;
      }
      
    } else if (lowerTranscript.contains('read') || lowerTranscript.contains('check')) {
      action = 'read_email';
      
    } else if (lowerTranscript.contains('reply')) {
      action = 'reply_email';
      body = transcript;
      
    } else if (lowerTranscript.contains('delete') || lowerTranscript.contains('remove')) {
      action = 'delete_email';
      
    } else if (lowerTranscript.contains('forward')) {
      action = 'forward_email';
      
    } else if (lowerTranscript.contains('save') && lowerTranscript.contains('contact')) {
      action = 'save_contact';
      
      final nameMatch = RegExp(r'save\s+([a-zA-Z\s]+)', caseSensitive: false).firstMatch(transcript);
      if (nameMatch != null) {
        name = nameMatch.group(1)?.trim();
      }
      
      final emailMatch = RegExp(r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})', caseSensitive: false).firstMatch(transcript);
      if (emailMatch != null) {
        email = emailMatch.group(1)?.trim();
      }
      
    } else {
      action = 'unknown';
    }
    
    return CommandResult(
      action: action,
      recipient: recipient,
      subject: subject,
      body: body,
      name: name,
      email: email,
    );
  }

  Future<bool> isConfirmation(String transcript) async {
    if (_apiKey.isEmpty || _apiKey == 'placeholder-key') {
      return _fallbackIsConfirmation(transcript);
    }

    try {
      final prompt = '''
      Determine if the following voice response is a confirmation or denial:
      
      "$transcript"
      
      Return only "true" if it's a confirmation (yes, sure, okay, confirm, etc.) or "false" if it's a denial or anything else.
      ''';

      final response = await http.post(
        Uri.parse('$_apiEndpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'topP': 0.8,
            'topK': 40
          }
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final textContent = jsonResponse['candidates'][0]['content']['parts'][0]['text'].toLowerCase().trim();
        
        return textContent == 'true';
      } else {
        throw Exception('Gemini API confirmation request failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _logger.severe("Gemini API confirmation error", e, stackTrace);
      throw Exception('Gemini API confirmation service failed: $e');
    }
  }

  bool _fallbackIsConfirmation(String transcript) {
    final lowerTranscript = transcript.toLowerCase().trim();
    
    final confirmWords = ['yes', 'yeah', 'sure', 'okay', 'ok', 'confirm', 'send', 'proceed', 'correct'];
    final denyWords = ['no', 'nope', 'cancel', 'stop', 'abort', 'don\'t', 'wrong'];
    
    for (final word in confirmWords) {
      if (lowerTranscript.contains(word)) {
        return true;
      }
    }
    
    for (final word in denyWords) {
      if (lowerTranscript.contains(word)) {
        return false;
      }
    }
    
    return false;
  }
}
