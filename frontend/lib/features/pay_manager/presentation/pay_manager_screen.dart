import 'package:flutter/material.dart';

class PayManagerScreen extends StatelessWidget {
  const PayManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Pay Manager',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Salary, bonuses, and payment processing...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
