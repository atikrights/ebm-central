import 'package:flutter/material.dart';

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sensors_rounded,
                size: 64,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'LIVE BROADCAST CHANNEL',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Signal encrypted. Waiting for transmission...',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
