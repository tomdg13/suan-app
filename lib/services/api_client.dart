import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ApiClient {
  static const _tokenKey = 'access_token';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _handle(String method, Uri uri, http.Response res) {
    // ---- console logging: every request shows up in your `flutter run` terminal ----
    debugPrint('[API] $method $uri -> ${res.statusCode}');
    if (res.body.isNotEmpty) {
      final preview = res.body.length > 500 ? '${res.body.substring(0, 500)}...' : res.body;
      debugPrint('[API] response body: $preview');
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }

    String message = 'Request failed (${res.statusCode})';
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['message'] != null) {
        message = body['message'] is List
            ? (body['message'] as List).join(', ')
            : body['message'].toString();
      }
    } catch (_) {}

    debugPrint('[API] ERROR $method $uri -> ${res.statusCode}: $message');
    throw ApiException(message, res.statusCode);
  }

  Future<dynamic> get(String path, {bool auth = false}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    try {
      final res = await http.get(uri, headers: await _headers(auth: auth));
      return _handle('GET', uri, res);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('[API] NETWORK ERROR GET $uri -> $e');
      throw ApiException('Could not reach server at $uri. Is the backend running and is the URL in constants.dart correct?');
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = false}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    debugPrint('[API] POST $uri body: ${jsonEncode(body)}');
    try {
      final res = await http.post(uri, headers: await _headers(auth: auth), body: jsonEncode(body));
      return _handle('POST', uri, res);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('[API] NETWORK ERROR POST $uri -> $e');
      throw ApiException('Could not reach server at $uri. Is the backend running and is the URL in constants.dart correct?');
    }
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body, {bool auth = false}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    debugPrint('[API] PATCH $uri body: ${jsonEncode(body)}');
    try {
      final res = await http.patch(uri, headers: await _headers(auth: auth), body: jsonEncode(body));
      return _handle('PATCH', uri, res);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('[API] NETWORK ERROR PATCH $uri -> $e');
      throw ApiException('Could not reach server at $uri. Is the backend running and is the URL in constants.dart correct?');
    }
  }

  Future<dynamic> delete(String path, {bool auth = false}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    try {
      final res = await http.delete(uri, headers: await _headers(auth: auth));
      return _handle('DELETE', uri, res);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('[API] NETWORK ERROR DELETE $uri -> $e');
      throw ApiException('Could not reach server at $uri. Is the backend running and is the URL in constants.dart correct?');
    }
  }
}
