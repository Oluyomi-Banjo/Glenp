class AppConstants {
  // Voice Recognition Constants
  static const int defaultVoiceTimeout = 5000; // milliseconds
  static const double defaultSpeechRate = 0.5;
  static const double defaultVolume = 1.0;
  static const double defaultPitch = 1.0;
  
  // Email Constants
  static const int maxEmailsToRead = 5;
  static const String defaultLanguageCode = 'en-US';
  
  // UI Constants
  static const double voiceButtonSize = 100.0;
  static const double statusIndicatorSize = 20.0;
  
  // Error Messages
  static const String authenticationFailedMessage = "Authentication failed. Please try again.";
  static const String voiceRecognitionFailedMessage = "Sorry, I couldn't hear you. Please try again.";
  static const String emailSendFailedMessage = "Failed to send email. Please try again.";
  static const String emailReadFailedMessage = "Failed to read emails. Please try again.";
  static const String contactSaveFailedMessage = "Failed to save contact. Please try again.";
  
  // Success Messages
  static const String emailSentSuccessMessage = "Email sent successfully.";
  static const String contactSavedSuccessMessage = "Contact saved successfully.";
  static const String authenticationSuccessMessage = "Authentication successful.";
  
  // Voice Commands
  static const List<String> confirmationWords = [
    'yes', 'yeah', 'sure', 'okay', 'ok', 'confirm', 'send', 'proceed'
  ];
  
  static const List<String> denialWords = [
    'no', 'nope', 'cancel', 'stop', 'abort', 'don\'t'
  ];
  
  // Email Actions
  static const String sendEmailAction = 'send_email';
  static const String readEmailAction = 'read_email';
  static const String replyEmailAction = 'reply_email';
  static const String deleteEmailAction = 'delete_email';
  static const String forwardEmailAction = 'forward_email';
  static const String saveContactAction = 'save_contact';
}
