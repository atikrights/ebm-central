import 'package:flutter/material.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Business Analysis',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Deep dive into organizational data...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class AnalysisCompanyScreen extends StatelessWidget {
  const AnalysisCompanyScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Analysis: Company', style: TextStyle(color: Colors.grey, fontSize: 18)));
}

class AnalysisProjectsScreen extends StatelessWidget {
  const AnalysisProjectsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Analysis: Projects', style: TextStyle(color: Colors.grey, fontSize: 18)));
}

class AnalysisPlanScreen extends StatelessWidget {
  const AnalysisPlanScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Analysis: Plan', style: TextStyle(color: Colors.grey, fontSize: 18)));
}

class AnalysisConsoleScreen extends StatelessWidget {
  const AnalysisConsoleScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Analysis: Console', style: TextStyle(color: Colors.grey, fontSize: 18)));
}

class AnalysisTasksScreen extends StatelessWidget {
  const AnalysisTasksScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Analysis: Tasks', style: TextStyle(color: Colors.grey, fontSize: 18)));
}
