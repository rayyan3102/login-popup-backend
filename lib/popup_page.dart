import 'package:flutter/material.dart';

class PopupPage extends StatelessWidget {
  final Map<String, dynamic> userData;

  const PopupPage({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('User Information'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Name: ${userData['name']}'),
          Text('Email: ${userData['email']}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
