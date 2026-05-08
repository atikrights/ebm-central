import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class ChatDashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat Dashboard',
              style: GoogleFonts.outfit(
                fontSize: 32, 
                fontWeight: FontWeight.bold, 
                color: isDark ? Colors.white : Colors.black87
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your communication overview here.',
              style: GoogleFonts.outfit(color: isDark ? Colors.white38 : Colors.black38, fontSize: 16),
            ),
            const SizedBox(height: 40),
            
            // Stats Row
            Row(
              children: [
                _buildStatBox('Total Chats', '124', Icons.forum_rounded, Colors.cyanAccent, isDark),
                const SizedBox(width: 20),
                _buildStatBox('Online Users', '45', Icons.online_prediction_rounded, Colors.greenAccent, isDark),
                const SizedBox(width: 20),
                _buildStatBox('Messages Today', '892', Icons.message_rounded, Colors.blueAccent, isDark),
              ],
            ),
            
            const SizedBox(height: 40),
            Text(
              'Recent Activity',
              style: GoogleFonts.outfit(
                fontSize: 22, 
                fontWeight: FontWeight.bold, 
                color: isDark ? Colors.white : Colors.black87
              ),
            ),
            const SizedBox(height: 20),
            
            // Placeholder for activity list
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
              ),
              child: Center(
                child: Text(
                  'Activity log will appear here.',
                  style: GoogleFonts.outfit(color: isDark ? Colors.white10 : Colors.black12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String title, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          boxShadow: [
            if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 20),
            Text(value, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text(title, style: GoogleFonts.outfit(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38)),
          ],
        ),
      ),
    );
  }
}
