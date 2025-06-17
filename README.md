# AI-Powered Facial Recognition Attendance System

## Overview

This application is a comprehensive attendance tracking system for educational institutions that leverages facial recognition, anti-spoofing techniques, and IoT integration to provide a secure and efficient attendance management solution. The system consists of a Flutter-based mobile application that communicates with a Raspberry Pi server to process attendance and control physical access.

## Features

- **Facial Recognition**: Real-time face detection and recognition using TensorFlow Lite models optimized for mobile devices
- **Anti-Spoofing Protection**: Multi-layer protection against photo and video attacks
- **Dual User Roles**: Separate interfaces for students and educators
- **Course Management**: Create, manage, and enroll in courses
- **Attendance Sessions**: Start, stop, and monitor attendance sessions
- **Real-time Synchronization**: Instant attendance marking and verification
- **IoT Integration**: Control physical access through Raspberry Pi
- **Privacy-First Design**: AES-256 encryption and local data storage
- **Offline Capabilities**: Function without constant internet connection
- **Dark Mode Support**: Full light and dark theme integration

## System Architecture

The system implements a client-server architecture with the following components:

1. **Mobile Application (Flutter)**: User interface for authentication, face enrollment, and attendance marking
2. **Raspberry Pi Server**: Processes facial recognition requests and controls access
3. **IoT Control Layer**: Interface between the recognition system and physical access mechanisms

## Technologies Used

- **Frontend**: Flutter/Dart
- **Machine Learning**: Google ML Kit, TensorFlow Lite
- **Backend**: Raspberry Pi with Python
- **IoT**: Raspberry Pi GPIO for access control
- **Security**: AES-256 encryption, challenge-response for liveness detection
- **Communication**: RESTful API over local network

## Testing and Performance

### Unit Testing
Each module—face recognition, encryption, face detection, anti-spoofing—was unit-tested in isolation to ensure functional correctness using JUnit (Android) and Pytest (Python).

### Integration Testing
Modules were integrated to ensure seamless data exchange and communication between mobile devices and the Raspberry Pi. The integration of TFLite models with the Android application and the IoT control layer was validated.

### Real-World Testing Scenarios
The system was subjected to:
- Variable lighting (natural light, low light, backlight)
- Different facial expressions and orientations
- Partial obstructions (sunglasses, masks)
- Spoof attacks (photos, videos)
- Mobile performance metrics (CPU load, battery drain)

### Security Tests
Tests confirmed:
- Encryption was taking place without data leakage
- Spoof detection algorithms detected non-live attempts
- Communication between app and Raspberry Pi was secure

### Performance Metrics

| Metric | Result |
|--------|--------|
| Recognition Accuracy | 96.3% |
| False Acceptance Rate (FAR) | 1.7% |
| False Rejection Rate (FRR) | 2.0% |
| Liveness Detection Success Rate | 94.8% |
| Average Latency (Raspberry Pi 4, Android) | 710 ms |
| Battery Drain (50 attempts on Android) | ~3.8% |
| Anti-Spoofing Performance (photo attacks) | 100% rejection |
| Anti-Spoofing Performance (video attacks) | 92.1% rejection |
| Recognition Time (TFLite model on Android) | ~550 ms (including preprocessing) |

## System Strengths

- **Real-Time Recognition**: Use of a light-weight CNN (MobiFace in TFLite) enables real-time face recognition within under 1 second on tested platforms
- **Privacy-First Design**: AES-256 encryption and local storage on Android, together with secure processing of keys, enables conformance to privacy standards such as GDPR
- **Robust Anti-Spoofing**: Protection against popular attacks with static images or video through multi-modal spoof detection (blink tracking, texture analysis, challenge-response prompts)
- **Edge-Friendly**: The algorithm performs well on low-power devices like Raspberry Pi 4 and mid-range Android smartphones
- **Ease of Use**: Simple user enrollment, authentication, and IoT triggering through the Android interface

## Limitations

- **Depth Sensing**: Without dedicated structured light or infrared hardware, 3D mask attack detection is partially effective
- **Lighting Sensitivity**: Accuracy is slightly lower in extremely low backlight or harsh shadow light conditions
- **Legacy Device Support**: Older Android devices without specialized neural accelerators experience slower response and slightly decreased accuracy

## Getting Started

### Prerequisites

- Flutter 2.19.0 or higher
- Android Studio / Xcode
- Raspberry Pi 4 (recommended) with Raspbian OS
- Python 3.7+ for the Raspberry Pi server

### Mobile App Setup

1. Clone the repository
2. Navigate to the mobile directory
3. Run `flutter pub get` to install dependencies
4. Update the server IP in `lib/utils/constants.dart`
5. Run the app using `flutter run`

### Raspberry Pi Setup

1. Install required Python packages
2. Configure the server application
3. Set up GPIO pins for access control (if applicable)
4. Run the server application

## User Guide

### For Students

1. Register with your institutional email
2. Enroll in your courses
3. Complete facial enrollment process
4. Check in to active attendance sessions using facial recognition

### For Educators

1. Register as an educator
2. Create and manage courses
3. Start attendance sessions
4. View and export attendance reports

## Security and Privacy

- All facial data is encrypted using AES-256
- Biometric templates are stored locally on the device
- Network communication is secured
- Challenge-response mechanisms prevent replay attacks

## Future Improvements

- Integration with institutional learning management systems
- Enhanced 3D mask detection
- Addition of thermal imaging for improved anti-spoofing
- Support for smartwatch-based student verification
- Blockchain integration for tamper-proof attendance records

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter and Dart teams for the mobile framework
- TensorFlow team for the machine learning tools
- Google ML Kit for face detection capabilities
- The open-source community for various libraries and tools used in this project
