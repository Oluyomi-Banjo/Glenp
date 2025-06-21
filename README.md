# Voice Email Assistant for Visually Impaired Users

A Flutter application designed specifically for visually impaired users that enables complete voice-based email management through natural language commands.

## Features

### 🔐 Security & Authentication
- Biometric authentication (fingerprint/face ID) on app launch
- Secure OAuth2 integration with Gmail API
- Supabase backend for contact storage

### 🎤 Voice Interaction
- Speech-to-Text for voice input
- Flutter TTS for voice output
- Gemini LLM for natural language processing
- Voice confirmation for all actions

### 📧 Email Management
- Send emails with voice commands
- Read inbox aloud (recent unread emails)
- Reply to emails
- Delete emails
- Forward emails
- Contact management with voice commands

### ♿ Accessibility Features
- Designed specifically for visually impaired users
- Voice-first interface with minimal visual elements
- Screen reader compatibility
- Large touch targets for easier interaction

## Setup Instructions

### 1. Prerequisites
- Flutter SDK (3.0.0 or higher)
- Android Studio / Xcode for mobile development
- Google Cloud Platform account
- Gmail API credentials
- Supabase account (already connected)

### 2. Environment Configuration

Create a \`.env\` file in the root directory with your actual API keys:

\`\`\`env
# Supabase Configuration (already connected)
SUPABASE_URL=your-actual-supabase-url
SUPABASE_KEY=your-actual-supabase-anon-key

# Google Cloud Configuration
GOOGLE_SERVICE_ACCOUNT={"type":"service_account","project_id":"your-project-id"}
GEMINI_API_KEY=your-gemini-api-key

# Gmail API Configuration
GMAIL_CLIENT_ID=your-gmail-client-id.apps.googleusercontent.com
GMAIL_CLIENT_SECRET=your-gmail-client-secret
\`\`\`

### 3. Database Setup ✅

The Supabase database is already configured with:
- \`contacts\` - User contacts with names and emails
- \`user_preferences\` - User settings and preferences
- \`email_logs\` - Email operation tracking

### 4. Installation Steps

Since you already have the project files:

\`\`\`bash
# Navigate to your project directory
cd /path/to/your/flutter-voice-email

# Install Flutter dependencies
flutter pub get

# For iOS (if developing for iOS)
cd ios && pod install && cd ..

# Run the app on connected device
flutter run
\`\`\`

### 5. API Setup Required

You still need to configure these APIs:

#### Speech-to-Text
- The app uses the \`speech_to_text\` Flutter plugin
- No additional API setup required for basic functionality
- For advanced features, you can optionally set up Google Cloud Speech-to-Text

#### Gemini API
1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create an API key
3. Add to your \`.env\` file as \`GEMINI_API_KEY\`

#### Gmail API
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Gmail API
3. Create OAuth2 credentials
4. Add client ID and secret to \`.env\` file

### 6. Testing

\`\`\`bash
# Run on Android device/emulator
flutter run

# Run on iOS device/simulator (macOS only)
flutter run -d ios

# Build for release
flutter build apk  # Android
flutter build ios  # iOS
\`\`\`

## Usage

### Voice Commands

#### Email Management
- "Send an email to John about meeting delay"
- "Read my emails"
- "Reply to the last email"
- "Delete this email"
- "Forward this email to Sarah"

#### Contact Management
- "Save Grace with email grace@gmail.com"
- "Find contact John"

#### Navigation
- "Go back"
- "Cancel"
- "Yes" / "No" for confirmations

### App Flow

1. **Launch**: Biometric authentication required
2. **Welcome**: App announces "Welcome, what would you like to do today?"
3. **Voice Input**: Tap microphone button and speak command
4. **Processing**: App processes command using Gemini LLM
5. **Confirmation**: App reads back action and asks for confirmation
6. **Execution**: Action is performed and result is announced

## Troubleshooting

### Common Issues

1. **Microphone Permission Denied**
   - Check app permissions in device settings
   - Restart the app after granting permissions

2. **Authentication Failed**
   - Ensure biometric authentication is set up on device
   - Check if device supports biometric authentication

3. **Voice Recognition Not Working**
   - Check internet connection (for Gemini API)
   - Ensure microphone is working properly
   - Grant microphone permissions

4. **Email Operations Failing**
   - Verify Gmail API credentials in \`.env\` file
   - Check OAuth2 setup
   - Ensure Gmail API is enabled in Google Cloud Console

## Project Structure

\`\`\`
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
├── screens/                  # UI screens
├── services/                 # Business logic services
├── providers/                # State management
├── widgets/                  # Reusable UI components
├── utils/                    # Utility functions
└── constants/                # App constants
\`\`\`

## Contributing

This is a final year project focused on accessibility for visually impaired users. Contributions should maintain the voice-first design principle and accessibility standards.

## License

This project is developed as an educational final year project.
