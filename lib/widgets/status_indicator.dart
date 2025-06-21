import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final bool isListening;
  final bool isProcessing;
  final String statusMessage;

  const StatusIndicator({
    super.key,
    required this.isListening,
    required this.isProcessing,
    required this.statusMessage,
  });

  @override
  Widget build(BuildContext context) {
    Color indicatorColor = Colors.grey;
    
    if (isListening) {
      indicatorColor = Colors.red;
    } else if (isProcessing) {
      indicatorColor = Colors.orange;
    } else if (statusMessage == "Ready") {
      indicatorColor = Colors.green;
    }

    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: indicatorColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          statusMessage,
          style: Theme.of(context).textTheme.bodyLarge,
          semanticsLabel: 'Status: $statusMessage',
        ),
      ],
    );
  }
}
