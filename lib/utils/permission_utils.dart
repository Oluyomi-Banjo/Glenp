import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  /// Check and request camera and photo library permissions
  /// Returns true if all permissions are granted, false if any are permanently denied
  /// Returns null if permissions are denied but not permanently
  static Future<bool?> checkCameraAndPhotosPermissions(
      BuildContext context) async {
    if (kDebugMode) {
      print('Checking camera and photos permissions...');
    }

    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses =
          await [Permission.camera, Permission.photos].request();

      PermissionStatus? statusCamera = statuses[Permission.camera];
      PermissionStatus? statusPhotos = statuses[Permission.photos];

      if (kDebugMode) {
        print(
            'Android permission status - Camera: $statusCamera, Photos: $statusPhotos');
      }

      bool isGranted = statusCamera == PermissionStatus.granted &&
          statusPhotos == PermissionStatus.granted;

      if (isGranted) {
        return true;
      }

      bool isPermanentlyDenied =
          statusCamera == PermissionStatus.permanentlyDenied ||
              statusPhotos == PermissionStatus.permanentlyDenied;

      if (isPermanentlyDenied) {
        return false;
      }

      // Permissions denied but not permanently
      return null;
    } else {
      // iOS permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.storage,
        Permission.photos
      ].request();

      PermissionStatus? statusCamera = statuses[Permission.camera];
      PermissionStatus? statusStorage = statuses[Permission.storage];
      PermissionStatus? statusPhotos = statuses[Permission.photos];

      if (kDebugMode) {
        print(
            'iOS permission status - Camera: $statusCamera, Storage: $statusStorage, Photos: $statusPhotos');
      }

      bool isGranted = statusCamera == PermissionStatus.granted &&
          statusStorage == PermissionStatus.granted &&
          statusPhotos == PermissionStatus.granted;

      if (isGranted) {
        return true;
      }

      bool isPermanentlyDenied =
          statusCamera == PermissionStatus.permanentlyDenied ||
              statusStorage == PermissionStatus.permanentlyDenied ||
              statusPhotos == PermissionStatus.permanentlyDenied;

      if (isPermanentlyDenied) {
        return false;
      }

      // Permissions denied but not permanently
      return null;
    }
  }

  /// Show settings dialog when permissions are permanently denied
  static Future<bool> showPermissionSettingsDialog(
    BuildContext context, {
    String title = 'Permission Required',
    String content =
        'This app needs camera and photo library access to function properly. Please grant these permissions in settings.',
    String cancelText = 'Cancel',
    String settingsText = 'Open Settings',
  }) async {
    final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(settingsText),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldOpenSettings) {
      if (kDebugMode) {
        print('Opening app settings...');
      }
      await openAppSettings();
    }

    return shouldOpenSettings;
  }
}
