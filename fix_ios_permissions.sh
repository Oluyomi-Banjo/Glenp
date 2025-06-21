#!/bin/zsh

echo "📱 Fixing iOS permissions for Flutter Voice Email Assistant..."
echo "⚡ Running flutter clean..."
flutter clean

echo "📦 Running flutter pub get..."
flutter pub get

echo "🍎 Running pod install..."
cd ios && pod install

echo "✅ All done! Your iOS permissions should now be properly configured."
echo "🚀 You can now run your app again."
