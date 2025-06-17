class ApiConstants {
  // Change this to the Raspberry Pi's IP address when deployed
  static const String baseUrl = 'http://192.168.4.1:8001';

  // API endpoints
  static const String login = '/api/login';
  static const String register = '/api/register';
  static const String me = '/api/me';
  static const String courses = '/api/courses';
  static const String sessions = '/api/attendance/sessions';
  static const String faceEnroll = '/api/face/enroll';
  static const String faceCheckIn = '/api/face/check-in';
  static const String livenessCheck = '/api/face/liveness-check';
  static const String ping =
      '/api/ping'; // May not exist, used for connectivity testing
  static const String enrollment = '/api/courses/enroll';
}

class AppConstants {
  static const String appName = 'University Attendance';
  static const double defaultPadding = 16.0;
  static const double borderRadius = 10.0;

  // Liveness detection
  static const int livenessCheckDuration = 3; // seconds
  static const List<String> livenessActions = [
    'Blink',
    'Turn Left',
    'Turn Right'
  ];
}
