import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/auth_provider.dart';

class SSOGateScreen extends StatefulWidget {
  final String? targetUrl;
  const SSOGateScreen({super.key, this.targetUrl});

  @override
  State<SSOGateScreen> createState() => _SSOGateScreenState();
}

class _SSOGateScreenState extends State<SSOGateScreen> {
  String? _userName;
  String? _userRole;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name');
      _userRole = prefs.getString('user_role');
      _isChecking = false;
    });
  }

  Future<void> _authorize() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('ebm_secure_device_id') ?? '';
    final token = await SecureLocalStore.readDecrypted('auth_token', deviceId);
    
    if (token != null && widget.targetUrl != null) {
      String target;
      try {
        // Decode Base64 target for security and professional look
        target = utf8.decode(base64Url.decode(widget.targetUrl!));
      } catch (e) {
        // Fallback if not encoded
        target = widget.targetUrl!;
      }
      
      // Handle App Scheme Redirection (ebm-app://...)
      if (target.startsWith('ebm-app://')) {
        final callbackUrl = Uri.parse(target).replace(
          queryParameters: {'token': token},
        );
        if (await canLaunchUrl(callbackUrl)) {
          await launchUrl(callbackUrl, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // Handle Web Redirection
      if (kIsWeb) {
        final uri = Uri.parse(target);
        final ssoUri = uri.replace(
          fragment: '/sso-callback?token=$token',
        );
        html.window.location.href = ssoUri.toString();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_userName == null) {
      // Not logged in to Central, redirect to login with return path
      if (kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final currentPath = html.window.location.hash.replaceAll('#', '');
          html.window.location.href = '/#/login?redirect=$currentPath'; 
        });
      }
      return const Scaffold();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security_rounded, size: 48, color: Color(0xFF3B82F6)),
              const SizedBox(height: 24),
              const Text(
                'Authorize EBM App',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'EBM App wants to access your identity',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              const SizedBox(height: 32),
              
              // User Profile Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF3B82F6),
                      child: Text(_userName![0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_userName!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(_userRole ?? 'User', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _authorize,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Continue as $_userName'),
                ),
              ),
              
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  if (widget.targetUrl != null) html.window.location.href = widget.targetUrl!;
                },
                child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
