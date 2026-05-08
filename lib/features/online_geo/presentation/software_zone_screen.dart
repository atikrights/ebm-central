import 'package:flutter/material.dart';

class SoftwareZoneScreen extends StatelessWidget {
  const SoftwareZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.terminal_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Software Zone',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Enterprise software solutions and deployment...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
