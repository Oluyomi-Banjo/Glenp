import 'package:flutter/material.dart';

class VoiceActionButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback onPressed;

  const VoiceActionButton({
    super.key,
    required this.isListening,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening ? Colors.red : Colors.blue,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            isListening ? Icons.mic : Icons.mic_none,
            size: 50,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
