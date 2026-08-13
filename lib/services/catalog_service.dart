import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/category.dart';
import '../models/unit.dart';
import 'api_client.dart';

class CatalogService {
  final ApiClient _api = ApiClient();

  Future<List<ProductCategory>> getCategories() async {
    final json = await _api.get('/categories');
    return (json as List).map((e) => ProductCategory.fromJson(e)).toList();
  }

  Future<List<ProductUnit>> getUnits() async {
    final json = await _api.get('/units');
    return (json as List).map((e) => ProductUnit.fromJson(e)).toList();
  }

  Future<List<ProductCategory>> getCategoriesAdmin() async {
    final json = await _api.get('/admin/categories', auth: true);
    return (json as List).map((e) => ProductCategory.fromJson(e)).toList();
  }

  Future<ProductCategory> createCategory({
    required String nameLao,
    String? nameEn,
    int sortOrder = 0,
    Uint8List? imageBytes,
  }) async {
    final fields = <String, String>{
      'nameLao': nameLao,
      if (nameEn != null && nameEn.isNotEmpty) 'nameEn': nameEn,
      'sortOrder': sortOrder.toString(),
    };
    final response = await _multipartRequest(method: 'POST', path: '/categories', imageBytes: imageBytes, fields: fields);
    return ProductCategory.fromJson(response);
  }

  Future<ProductCategory> updateCategory(int id, {String? nameLao, String? nameEn, int? sortOrder, int? isActive, Uint8List? imageBytes}) async {
    final fields = <String, String>{
      if (nameLao != null) 'nameLao': nameLao,
      if (nameEn != null) 'nameEn': nameEn,
      if (sortOrder != null) 'sortOrder': sortOrder.toString(),
      if (isActive != null) 'isActive': isActive.toString(),
    };
    final response = await _multipartRequest(method: 'PATCH', path: '/categories/$id', imageBytes: imageBytes, fields: fields);
    return ProductCategory.fromJson(response);
  }

  Future<void> deleteCategory(int id) async {
    final token = await _api.getToken();
    final uri = Uri.parse('\${ApiConfig.baseUrl}/categories/\$id');
    final headers = <String, String>{};
    if (token != null) headers['Authorization'] = 'Bearer \$token';
    final response = await http.delete(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Delete failed (\${response.statusCode})', response.statusCode);
    }
  }

  Future<Map<String, dynamic>> _multipartRequest({required String method, required String path, Uint8List? imageBytes, Map<String, String> fields = const {}}) async {
    final token = await _api.getToken();
    final uri = Uri.parse('\${ApiConfig.baseUrl}\$path');
    final request = http.MultipartRequest(method, uri);
    if (token != null) request.headers['Authorization'] = 'Bearer \$token';
    request.fields.addAll(fields);
    if (imageBytes != null) {
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'category.jpg'));
    }
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    }
    String message = 'Request failed (\${response.statusCode})';
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map && body['message'] != null) {
        message = body['message'] is List ? (body['message'] as List).join(', ') : body['message'].toString();
      }
    } catch (_) {}
    throw ApiException(message, response.statusCode);
  }
}
