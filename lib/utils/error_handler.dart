import '../services/tts_service.dart';
import 'package:logging/logging.dart';
import 'app_logger.dart';

class ErrorHandler {
  static final TTSService _ttsService = TTSService();
  static final Logger _logger = AppLogger.getLogger('ErrorHandler');
  
  static Future<void> handleError(dynamic error, {String? customMessage, StackTrace? stackTrace}) async {
    // Log error for debugging
    _logger.severe('Error occurred', error, stackTrace);
    
    // Determine appropriate user message
    String userMessage = customMessage ?? _getErrorMessage(error);
    
    // Speak error message to user
    await _ttsService.speak(userMessage);
  }
  
  static String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('permission')) {
      return "Permission denied. Please check your app permissions.";
    } else if (errorString.contains('network') || errorString.contains('connection')) {
      return "Network error. Please check your internet connection.";
    } else if (errorString.contains('authentication') || errorString.contains('auth')) {
      return "Authentication error. Please try logging in again.";
    } else if (errorString.contains('timeout')) {
      return "Request timed out. Please try again.";
    } else if (errorString.contains('microphone') || errorString.contains('audio')) {
      return "Microphone error. Please check your microphone permissions.";
    } else if (errorString.contains('email')) {
      return "Email service error. Please try again later.";
    } else {
      return "An unexpected error occurred. Please try again.";
    }
  }
  
  static Future<void> handleNetworkError() async {
    await _ttsService.speak(
      "Network connection error. Please check your internet connection and try again."
    );
  }
  
  static Future<void> handleAuthenticationError() async {
    await _ttsService.speak(
      "Authentication failed. Please verify your credentials and try again."
    );
  }
  
  static Future<void> handleVoiceRecognitionError() async {
    await _ttsService.speak(
      "I couldn't understand what you said. Please speak clearly and try again."
    );
  }
  
  static Future<void> handleEmailServiceError() async {
    await _ttsService.speak(
      "Email service is currently unavailable. Please try again later."
    );
  }
}
