import 'package:flutter/material.dart';
import 'package:attendance_app/main.dart';

/// A utility class for UI utilities (removed platform specificity)
class PlatformUtils {
  /// Shows a snackbar safely using the global ScaffoldMessenger
  static void showSnackBar(String message, {Duration? duration}) {
    MyApp.scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
  
  /// Creates a loading indicator
  static Widget getLoadingIndicator({Color? color}) {
    return CircularProgressIndicator(color: color);
  }
  
  /// Creates a button
  static Widget buildButton({
    required VoidCallback onPressed,
    required String text,
    Color? backgroundColor,
    Color? textColor,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: textColor,
        backgroundColor: backgroundColor,
      ),
      child: Text(text),
    );
  }
  
  /// Creates an app bar
  static PreferredSizeWidget buildAppBar({
    required String title,
    List<Widget>? actions,
    Widget? leading,
  }) {
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
    );
  }
  
  /// Shows a dialog
  static Future<T?> showPlatformDialog<T>({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (cancelText != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onCancel != null) onCancel();
              },
              child: Text(cancelText),
            ),
          if (confirmText != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onConfirm != null) onConfirm();
              },
              child: Text(confirmText),
            ),
        ],
      ),
    );
  }
  
  /// Ensures widgets have a Material ancestor
  static Widget wrapWithMaterial(Widget child, {MaterialType type = MaterialType.transparency}) {
    return Material(type: type, child: child);
  }
  
  /// Creates a form field container
  static Widget formFieldContainer({required Widget child}) {
    return wrapWithMaterial(
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey[200],
        ),
        child: child,
      ),
    );
  }
}