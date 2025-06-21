import '../constants/app_constants.dart';

class VoiceCommandParser {
  static bool isConfirmation(String transcript) {
    final lowerTranscript = transcript.toLowerCase().trim();
    
    return AppConstants.confirmationWords.any(
      (word) => lowerTranscript.contains(word)
    );
  }
  
  static bool isDenial(String transcript) {
    final lowerTranscript = transcript.toLowerCase().trim();
    
    return AppConstants.denialWords.any(
      (word) => lowerTranscript.contains(word)
    );
  }
  
  static String extractEmailAction(String transcript) {
    final lowerTranscript = transcript.toLowerCase();
    
    if (lowerTranscript.contains('send') || lowerTranscript.contains('compose')) {
      return AppConstants.sendEmailAction;
    } else if (lowerTranscript.contains('read') || lowerTranscript.contains('check')) {
      return AppConstants.readEmailAction;
    } else if (lowerTranscript.contains('reply')) {
      return AppConstants.replyEmailAction;
    } else if (lowerTranscript.contains('delete') || lowerTranscript.contains('remove')) {
      return AppConstants.deleteEmailAction;
    } else if (lowerTranscript.contains('forward')) {
      return AppConstants.forwardEmailAction;
    } else if (lowerTranscript.contains('save') && lowerTranscript.contains('contact')) {
      return AppConstants.saveContactAction;
    }
    
    return '';
  }
  
  static String extractRecipientName(String transcript) {
    final lowerTranscript = transcript.toLowerCase();
    
    // Look for patterns like "send email to John" or "email John"
    final patterns = [
      RegExp(r'(?:send|email|to)\s+(?:to\s+)?([a-zA-Z\s]+)', caseSensitive: false),
      RegExp(r'([a-zA-Z\s]+)(?:\s+email|\s+message)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(lowerTranscript);
      if (match != null) {
        return match.group(1)?.trim() ?? '';
      }
    }
    
    return '';
  }
  
  static String extractSubject(String transcript) {
    final lowerTranscript = transcript.toLowerCase();
    
    // Look for patterns like "subject is" or "about"
    final patterns = [
      RegExp(r'subject\s+(?:is\s+)?(.+)', caseSensitive: false),
      RegExp(r'about\s+(.+)', caseSensitive: false),
      RegExp(r'regarding\s+(.+)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(lowerTranscript);
      if (match != null) {
        return match.group(1)?.trim() ?? '';
      }
    }
    
    return '';
  }
  
  static Map<String, String> extractContactInfo(String transcript) {
    final result = <String, String>{};
    
    // Extract name pattern: "save John" or "contact John"
    final namePattern = RegExp(r'(?:save|contact)\s+([a-zA-Z\s]+)', caseSensitive: false);
    final nameMatch = namePattern.firstMatch(transcript);
    if (nameMatch != null) {
      result['name'] = nameMatch.group(1)?.trim() ?? '';
    }
    
    // Extract email pattern: "email john@example.com" or "with email john@example.com"
    final emailPattern = RegExp(r'(?:email|with email)\s+([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})', caseSensitive: false);
    final emailMatch = emailPattern.firstMatch(transcript);
    if (emailMatch != null) {
      result['email'] = emailMatch.group(1)?.trim() ?? '';
    }
    
    return result;
  }
}
