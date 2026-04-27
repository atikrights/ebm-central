import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ─── ApiService Provider ───────────────────────────────────────────────────
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// EBM Central API Service
/// 
/// Security Features:
/// - All requests include 'X-EBM-Client' header for server-side validation.
/// - Authorization Bearer token is injected on every authenticated request.
/// - Consistent error handling with typed [ApiException] for the UI layer.
/// - Production URL detection is automatic based on the current host.
class ApiService {
  // ─── Base URL (Auto-detects Production vs Local) ─────────────────────────
  String get baseUrl {
    if (const bool.fromEnvironment('dart.library.html')) {
      final String host = Uri.base.host;
      if (host == 'central.ebfic.store') {
        return 'https://central.ebfic.store/api/public/api';
      }
      if (host.isNotEmpty && host != 'localhost') {
        return 'https://$host/api/public/api';
      }
    }
    return 'http://localhost:8000/api';
  }

  String? token;

  void setToken(String newToken) => token = newToken;
  void clearToken() => token = null;

  // ─── Default Security Headers ─────────────────────────────────────────────
  // 'X-EBM-Client' lets the backend log which platform made the request.
  // 'X-Requested-With' prevents CSRF from simple HTML form attacks.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-EBM-Client': 'ebm-central-flutter',
        'X-Requested-With': 'XMLHttpRequest',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ─── GET ─────────────────────────────────────────────────────────────────
  Future<dynamic> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
      );
      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', statusCode: 0);
    }
  }

  // ─── POST ─────────────────────────────────────────────────────────────────
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: json.encode(data),
      );
      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', statusCode: 0);
    }
  }

  // ─── PUT ─────────────────────────────────────────────────────────────────
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: json.encode(data),
      );
      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', statusCode: 0);
    }
  }

  // ─── DELETE ───────────────────────────────────────────────────────────────
  Future<dynamic> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
      );
      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', statusCode: 0);
    }
  }

  // ─── Response Handler ─────────────────────────────────────────────────────
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    }

    // Try to extract a backend error message
    String message = 'Request failed ($statusCode)';
    try {
      final body = json.decode(response.body);
      message = body['message'] ?? body['error'] ?? message;
    } catch (_) {}

    if (statusCode == 401) throw ApiException('Unauthorized. Please log in again.', statusCode: 401);
    if (statusCode == 403) throw ApiException('Access denied: $message', statusCode: 403);
    if (statusCode == 422) throw ApiException('Validation error: $message', statusCode: 422);
    if (statusCode == 429) throw ApiException('Too many requests. Please wait.', statusCode: 429);
    // Let the real backend error message pass through for 500 errors if it exists.
    if (statusCode >= 500 && message == 'Request failed ($statusCode)') {
       throw ApiException('Server error. Please try again later.', statusCode: statusCode);
    }
    throw ApiException(message, statusCode: statusCode);
  }
}

// ─── Typed API Exception ──────────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException(this.message, {required this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
