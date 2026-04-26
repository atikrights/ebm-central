import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// 1. ApiService Provider
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web/Desktop
  // Dynamic base URL for local and production
  String get baseUrl {
    if (const bool.fromEnvironment('dart.library.html')) {
      final String host = Uri.base.host;
      if (host == 'central.ebfic.store') {
        return 'https://central.ebfic.store/api/public/api'; // Hostinger public_html path
      }
      if (host.isNotEmpty && host != 'localhost') {
         return 'https://$host/api/public/api';
      }
    }
    return 'http://localhost:8000/api';
  }
  String? token; // JWT token from Laravel

  void setToken(String newToken) {
    token = newToken;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String endpoint) async {
    final response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: _headers);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to post data: ${response.statusCode}');
    }
  }
}
