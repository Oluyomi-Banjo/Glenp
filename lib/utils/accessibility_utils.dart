import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class AccessibilityUtils {
  static void announceForAccessibility(BuildContext context, String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  static Widget accessibleButton({
    required VoidCallback onPressed,
    required Widget child,
    String? label,
    String? hint,
  }) {
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      child: GestureDetector(
        onTap: onPressed,
        child: child,
      ),
    );
  }

  static Widget accessibleText(String text, {TextStyle? style}) {
    return Semantics(
      label: text,
      child: Text(
        text,
        style: style,
      ),
    );
  }
}
