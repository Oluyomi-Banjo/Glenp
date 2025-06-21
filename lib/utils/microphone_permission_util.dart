import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logging/logging.dart';
import 'app_logger.dart';

/// A utility class to handle microphone permission requests and checks
class MicrophonePermissionUtil {
  static final Logger _logger = AppLogger.getLogger('MicrophonePermissionUtil');

  /// Checks and requests microphone permission
  /// Returns true if permission is granted, false otherwise
  static Future<bool> checkAndRequestMicrophonePermission(
      BuildContext context) async {
    _logger.info('Checking microphone permission status...');
    final status = await Permission.microphone.status;
    _logger.info('Microphone permission status: $status');

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      _logger.info('Requesting microphone permission...');
      final requestStatus = await Permission.microphone.request();
      _logger.info('Microphone permission request result: $requestStatus');

      if (requestStatus.isGranted) {
        return true;
      }
    }

    // Handle permanently denied case
    if (status.isPermanentlyDenied) {
      _logger.warning('Microphone permission permanently denied');
      await _showPermissionDeniedDialog(context);
      return false;
    }

    return false;
  }

  /// Shows a dialog when permission is permanently denied
  static Future<void> _showPermissionDeniedDialog(BuildContext context) async {
    if (!context.mounted) return;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Microphone Permission Required'),
          content: const Text(
              'This app requires microphone access to capture your voice commands. '
              'Please enable it in your device settings.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                openAppSettings();
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
