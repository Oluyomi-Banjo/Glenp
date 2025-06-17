#!/bin/bash

echo "Applying camera permission fixes..."

# Navigate to the project directory
cd "$(dirname "$0")"

echo "Running flutter clean..."
flutter clean

echo "Running flutter pub get..."
flutter pub get

echo "Moving to iOS directory..."
cd ios

echo "Running pod install..."
pod install

cd ..

echo "All done! Please run your app now."
echo "If you still have permission issues, try restarting your iOS simulator or device."
