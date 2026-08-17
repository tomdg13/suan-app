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

  /// NOTE: title/subtitle/linkUrl are always sent here, even as empty
  /// strings — NOT conditionally like createBanner(). This lets the
  /// caller actually CLEAR a field on an existing banner. If we only
  /// sent non-null values, emptying a field in the form and saving
  /// would omit it from the request entirely, and the backend's
  /// Object.assign(banner, dto) would leave the old value untouched —
  /// the field would silently fail to clear.
  Future<BannerItem> updateBanner(
    int id, {
    Uint8List? imageBytes,
    required String title,
    required String subtitle,
    required String linkUrl,
    bool? isActive,
  }) async {
    final response = await _multipartRequest(
      method: 'PATCH',
      path: '/banners/$id',
      imageBytes: imageBytes,
      fields: {
        'title': title,
        'subtitle': subtitle,
        'linkUrl': linkUrl,
        if (isActive != null) 'isActive': isActive ? '1' : '0',
      },
    );
    return BannerItem.fromJson(response);
  }

  /// PATCH /banners/reorder — persists new sort_order values after a
  /// drag-and-drop reorder in the admin UI.
  Future<void> reorderBanners(List<int> orderedIds) async {
    final items = [
      for (var i = 0; i < orderedIds.length; i++)
        {'id': orderedIds[i], 'sortOrder': i + 1},
    ];
    await _api.patch('/banners/reorder', {'items': items}, auth: true);
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
