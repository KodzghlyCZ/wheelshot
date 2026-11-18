import 'package:flutter/material.dart';

/// Asks before abandoning an in-progress shoot and returning home.
Future<bool> confirmLeaveToHome(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Leave to home?'),
      content: const Text(
        'You’ll go back to the home screen. Photos already saved in this '
        'session folder stay on disk.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Stay'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
  return result == true;
}

Future<void> leaveToHome(BuildContext context) async {
  final ok = await confirmLeaveToHome(context);
  if (!ok || !context.mounted) return;
  Navigator.of(context).popUntil((r) => r.isFirst);
}
