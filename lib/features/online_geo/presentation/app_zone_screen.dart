import 'package:flutter/material.dart';

class AppZoneScreen extends StatelessWidget {
  const AppZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.app_shortcut_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'App Zone',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Mobile application distribution and monitoring...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
