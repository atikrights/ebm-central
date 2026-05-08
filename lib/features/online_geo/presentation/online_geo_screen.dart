import 'package:flutter/material.dart';

class OnlineGeoScreen extends StatelessWidget {
  const OnlineGeoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.language_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Online Geo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Global online connectivity and metrics...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
