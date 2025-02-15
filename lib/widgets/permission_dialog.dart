import 'package:flutter/material.dart';
import '../main.dart'; // Import navigatorKey

Future<bool?> showPermissionDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Storage Permission Required'),
      content: const Text(
        'NotPixelShot needs access to storage to scan and index your screenshots. '
        'Without this permission, the app cannot function properly.',
      ),
      actions: [
        TextButton(
          child: const Text('Deny'),
          onPressed: () => Navigator.pop(context, false),
        ),
        TextButton(
          child: const Text('Allow'),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
}
