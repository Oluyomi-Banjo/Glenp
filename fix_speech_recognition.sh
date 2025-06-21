#!/bin/zsh

echo "🎤 Fixing speech recognition issues in Flutter Voice Email Assistant..."

echo "⚡ Running flutter clean..."
flutter clean

echo "📦 Running flutter pub get..."
flutter pub get

echo "🍎 Running pod install..."
cd ios && pod install

echo "✅ All done! The speech recognition should now work properly."
echo "🚀 You can now run your app again."
echo ""
echo "📱 If you're still having issues:"
echo "   1. Make sure microphone permissions are granted in device settings"
echo "   2. Restart your application completely"
echo "   3. Try using headphones with a microphone for better audio capture"
