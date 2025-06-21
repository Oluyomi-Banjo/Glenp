#!/bin/zsh

echo "🎤 Fixing microphone permissions for Flutter Voice Email Assistant..."

echo "⚡ Running flutter clean..."
flutter clean

echo "📦 Running flutter pub get..."
flutter pub get

echo "🍎 Running pod install..."
cd ios && pod install

echo "✅ All done! Your iOS microphone permissions should now be properly configured."
echo "🚀 You can now run your app again."
echo ""
echo "📱 If you're still having permission issues:"
echo "   1. For iOS simulator: Reset the simulator (Device menu > Erase All Content and Settings)"
echo "   2. For physical iOS devices: Go to Settings > Your App > Permissions and make sure they're enabled"
