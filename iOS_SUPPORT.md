# iOS Support Guide

This document provides guidance on running and optimizing the University Attendance System on iOS devices.

## Prerequisites

- macOS computer for iOS development
- Xcode 13.0 or later
- iOS 13.0 or later target device
- Apple Developer account (for deploying to physical devices)
- CocoaPods installed (`sudo gem install cocoapods`)

## Setup Instructions

1. Clone the repository and navigate to the mobile directory:
   ```
   cd attendance_system/mobile
   ```

2. Install Flutter dependencies:
   ```
   flutter pub get
   ```

3. Navigate to the iOS folder and install CocoaPods dependencies:
   ```
   cd ios
   pod install
   cd ..
   ```

4. Open the project in Xcode:
   ```
   open ios/Runner.xcworkspace
   ```

5. In Xcode, select your team for code signing.

6. Connect your iOS device or select an iOS simulator.

7. Run the app:
   ```
   flutter run
   ```

## iOS-Specific Optimizations

The app includes the following iOS-specific optimizations:

1. **Camera Configuration**
   - Uses BGRA8888 image format for better iOS face detection
   - Optimizes camera parameters for iOS devices

2. **Face Detection**
   - Platform-specific face detection settings
   - Customized ML Kit implementation for iOS

3. **UI Adaptations**
   - iOS-native UI elements when running on iOS devices
   - Proper permission handling for iOS

## Troubleshooting

### Camera Permission Issues
If the camera doesn't work on iOS, ensure you have:
- Granted camera permissions when prompted
- Verified the NSCameraUsageDescription in Info.plist

### Face Detection Issues
If face detection is not working properly:
- Ensure good lighting conditions
- Position your face within the guide overlay
- Check internet connectivity for server-based verifications

### Build Issues
If encountering build errors:
- Update CocoaPods: `pod repo update`
- Clean build folder: `flutter clean`
- Update Xcode to the latest version

## iOS Distribution

To prepare the app for App Store submission:

1. Update version in pubspec.yaml
2. Generate iOS release build:
   ```
   flutter build ios --release
   ```
3. Open Xcode and use the Archive feature
4. Follow App Store Connect submission process

## Technical Notes

- The app uses platform detection to apply iOS-specific behaviors
- Camera and ML Kit configurations are optimized for iOS devices
- Face detection uses iOS-optimized algorithms when running on iOS
