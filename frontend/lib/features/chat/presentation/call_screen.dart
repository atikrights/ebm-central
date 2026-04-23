import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';
import 'chat_detail_screen.dart';

class CallScreen extends StatefulWidget {
  final String name;
  final String avatar;
  final bool isVideo;

  const CallScreen({
    super.key,
    required this.name,
    required this.avatar,
    this.isVideo = true,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isScreenSharing = false;

  @override
  void initState() {
    super.initState();
    // Initialize Global Call State via Controller
    CallController.instance.startCall(
      name: widget.name, 
      avatar: widget.avatar, 
      isVideo: widget.isVideo
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background - Main Feed
          _buildMainFeed(),

          // Glassy Top Bar
          _buildTopBar(),

          // Participant Floating Feed
          if (_isScreenSharing) _buildFloatingParticipant(),

          // Bottom Controls
          _buildControlBar(),
        ],
      ),
    );
  }

  Widget _buildMainFeed() {
    if (_isScreenSharing) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1542831371-29b0f74f9713?auto=format&fit=crop&w=1920&q=80'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withOpacity(0.4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.screen_share, size: 60, color: Colors.blue.withOpacity(0.8)),
              const SizedBox(height: 16),
              const Text('Sharing your screen...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300)),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F1117),
            const Color(0xFF1E222D).withOpacity(0.8),
            const Color(0xFF0F1117),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'avatar_${widget.name}',
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue.withOpacity(0.3), width: 4),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 40, spreadRadius: 10),
                  ],
                  image: DecorationImage(image: NetworkImage(widget.avatar), fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -1)),
            const SizedBox(height: 8),
            Text(_isCameraOff ? 'Camera Off' : 'Ringing...', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 40,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _barButton(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
          GlassCard(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, size: 14, color: Colors.green),
                  SizedBox(width: 8),
                  Text('End-to-end Encrypted', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
          _barButton(Icons.person_add_outlined, () {}),
        ],
      ),
    );
  }

  Widget _buildFloatingParticipant() {
    return Positioned(
      top: 100,
      right: 20,
      child: GestureDetector(
        child: Container(
          width: 120,
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            image: DecorationImage(image: NetworkImage(widget.avatar), fit: BoxFit.cover),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _controlIcon(_isMuted ? Icons.mic_off : Icons.mic, _isMuted ? Colors.red : Colors.white, () => setState(() => _isMuted = !_isMuted)),
                  const SizedBox(width: 15),
                  _controlIcon(_isCameraOff ? Icons.videocam_off : Icons.videocam, _isCameraOff ? Colors.red : Colors.white, () => setState(() => _isCameraOff = !_isCameraOff)),
                  const SizedBox(width: 15),
                  _controlIcon(Icons.screen_share, _isScreenSharing ? Colors.blue : Colors.white, () => setState(() => _isScreenSharing = !_isScreenSharing), isSpecial: true),
                  const SizedBox(width: 15),
                  _controlIcon(Icons.chat_bubble_outline, Colors.white, () {}),
                  const SizedBox(width: 30),
                  GestureDetector(
                    onTap: () {
                      // End Call Logic: Clear State & Update UI Globally
                      ChatDetailScreen.endCall(context);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _barButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _controlIcon(IconData icon, Color color, VoidCallback onTap, {bool isSpecial = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSpecial && color == Colors.blue ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
