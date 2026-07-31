import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/banner_item.dart';
import 'api_client.dart';

class BannerService {
  final ApiClient _api = ApiClient();

  /// Public — active banners only, for the storefront carousel.
  Future<List<BannerItem>> getActiveBanners() async {
    final json = await _api.get('/banners');
    return (json as List).map((e) => BannerItem.fromJson(e)).toList();
  }

  /// Admin — every banner, including hidden ones.
  Future<List<BannerItem>> getAllBanners() async {
    final json = await _api.get('/banners/all', auth: true);
    return (json as List).map((e) => BannerItem.fromJson(e)).toList();
  }

  Future<BannerItem> createBanner({
    required Uint8List imageBytes,
    String? title,
    String? subtitle,
    String? linkUrl,
  }) async {
    final response = await _multipartRequest(
      method: 'POST',
      path: '/banners',
      imageBytes: imageBytes,
      fields: {
        if (title != null) 'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (linkUrl != null) 'linkUrl': linkUrl,
      },
    );
    return BannerItem.fromJson(response);
  }

  Future<BannerItem> updateBanner(
    int id, {
    Uint8List? imageBytes,
    String? title,
    String? subtitle,
    String? linkUrl,
    bool? isActive,
  }) async {
    final response = await _multipartRequest(
      method: 'PATCH',
      path: '/banners/$id',
      imageBytes: imageBytes,
      fields: {
        if (title != null) 'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (linkUrl != null) 'linkUrl': linkUrl,
        if (isActive != null) 'isActive': isActive ? '1' : '0',
      },
    );
    return BannerItem.fromJson(response);
  }

  Future<void> deleteBanner(int id) async {
    final token = await _api.getToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}/banners/$id');
    final headers = <String, String>{};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final response = await http.delete(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Delete failed (${response.statusCode})', response.statusCode);
    }
  }

  Future<Map<String, dynamic>> _multipartRequest({
    required String method,
    required String path,
    Uint8List? imageBytes,
    Map<String, String> fields = const {},
  }) async {
    final token = await _api.getToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final request = http.MultipartRequest(method, uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    if (imageBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: 'banner.jpg'),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    }
    String message = 'Request failed (${response.statusCode})';
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map && body['message'] != null) {
        message = body['message'] is List
            ? (body['message'] as List).join(', ')
            : body['message'].toString();
      }
    } catch (_) {}
    throw ApiException(message, response.statusCode);
  }
}
