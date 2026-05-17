import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

// ─── ApiService Provider ────────────────-----------------------------------
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
  String get baseUrl => AppConfig.baseUrl;

  String? token;

  void setToken(String newToken) => token = newToken;
  void clearToken() => token = null;

  // ─── Default Security Headers ─────────────────────────────────────────────
  // 'X-EBM-Client' lets the backend log which platform made the request.
  // 'X-Requested-With' prevents CSRF from simple HTML form attacks.
  Map<String, String> _buildHeaders(String endpoint, [dynamic body]) {
    final base = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && !token!.codeUnits.any((char) => char < 32 || char > 126)) 
        'Authorization': 'Bearer $token',
    };

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timestampStr = timestamp.toString();
    final clientId = 'ebm-central-flutter';
    final secret = 'ebm_central_secure_secret_key_456';

    String content = '';
    if (body != null) {
      if (body is Map || body is List) {
        content = json.encode(body);
      } else {
        content = body.toString();
      }
    }

    final fullUrl = '$baseUrl$endpoint';
    final dataToSign = '$fullUrl|$timestampStr|$content';

    final keyBytes = utf8.encode(secret);
    final dataBytes = utf8.encode(dataToSign);
    final hmac = Hmac(sha256, keyBytes);
    final signature = hmac.convert(dataBytes).toString();

    base['X-EBM-Client'] = clientId;
    base['X-EBM-Timestamp'] = timestampStr;
    base['X-EBM-Signature'] = signature;

    return base;
  }

  // ─── GET ─────────────────────────────────────────────────────────────────
  Future<dynamic> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _buildHeaders(endpoint),
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
        headers: _buildHeaders(endpoint, data),
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
        headers: _buildHeaders(endpoint, data),
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
        headers: _buildHeaders(endpoint),
      );
      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', statusCode: 0);
    }
  }

  // ─── PATCH ────────────────────────────────────────────────────────────────
  Future<dynamic> patch(String endpoint, [Map<String, dynamic>? data]) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: _buildHeaders(endpoint, data),
        body: data != null ? json.encode(data) : null,
      );
      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', statusCode: 0);
    }
  }

  // ─── Response Handler ─────────────────────────────────────────────────────
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    final body = response.body;

    if (statusCode >= 200 && statusCode < 300) {
      if (body.isEmpty) return null;
      try {
        return json.decode(body);
      } catch (e) {
        debugPrint('❌ JSON Decode Error (Success Code but Invalid JSON):');
        debugPrint('Raw Body: $body');
        throw ApiException('Server returned invalid data format.', statusCode: statusCode);
      }
    }

    // Try to extract a backend error message
    String message = 'Request failed ($statusCode)';
    try {
      if (body.isNotEmpty) {
        final decodedBody = json.decode(body);
        message = decodedBody['message'] ?? decodedBody['error'] ?? message;
      }
    } catch (_) {
      // If we can't decode the error body, it might be HTML
      debugPrint('⚠️ Could not decode error response body as JSON. Status: $statusCode');
      if (body.contains('<html') || body.contains('<?php')) {
        debugPrint('Raw Error Body (HTML/PHP Detected): ${body.substring(0, body.length > 200 ? 200 : body.length)}...');
      }
    }

    if (statusCode == 401) throw ApiException('Unauthorized. Please log in again.', statusCode: 401);
    if (statusCode == 403) throw ApiException('Access denied: $message', statusCode: 403);
    if (statusCode == 422) throw ApiException('Validation error: $message', statusCode: 422);
    if (statusCode == 429) throw ApiException('Too many requests. Please wait.', statusCode: 429);
    
    throw ApiException(message, statusCode: statusCode);
  }
  // ─── POST MULTIPART ──────────────────────────────────────────────────────
  Future<dynamic> postMultipart(String endpoint, Map<String, String> fields, List<http.MultipartFile> files) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
      request.headers.addAll(_buildHeaders(endpoint, fields));
      request.headers['Content-Type'] = 'multipart/form-data';
      request.fields.addAll(fields);
      request.files.addAll(files);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', statusCode: 0);
    }
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
