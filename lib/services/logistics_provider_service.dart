import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../services/api_client.dart';

class LogisticsProvider {
  final int id;
  final String name;
  final String? description;
  final String type; // logistic | customer_courier | store_pickup
  final String? logoUrl;
  final bool isActive;
  final int sortOrder;

  LogisticsProvider({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    this.logoUrl,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory LogisticsProvider.fromJson(Map<String, dynamic> j) => LogisticsProvider(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        type: j['type'] as String? ?? 'logistic',
        logoUrl: j['logo_url'] as String?,
        isActive: j['is_active'] == 1 || j['is_active'] == true,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );
}

class LogisticsProviderService {
  final ApiClient _api = ApiClient();

  Future<List<LogisticsProvider>> fetchActive() async {
    final data = await _api.get('/logistics-provider?active=1');
    return (data as List).map((e) => LogisticsProvider.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<LogisticsProvider>> fetchAll() async {
    final data = await _api.get('/logistics-provider');
    return (data as List).map((e) => LogisticsProvider.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// PATCH /logistics-provider/reorder — persists new sort_order values
  /// after a drag-and-drop reorder in the admin UI.
  Future<void> reorderProviders(List<int> orderedIds) async {
    final items = [
      for (var i = 0; i < orderedIds.length; i++)
        {'id': orderedIds[i], 'sortOrder': i + 1},
    ];
    await _api.patch('/logistics-provider/reorder', {'items': items}, auth: true);
  }

  Future<LogisticsProvider> create({
    required String name,
    String? description,
    required String type,
    bool isActive = true,
    int sortOrder = 0,
    Uint8List? imageBytes,
  }) async {
    final response = await _multipartRequest(
      method: 'POST',
      path: '/logistics-provider',
      imageBytes: imageBytes,
      fields: {
        'name': name,
        'description': description ?? '',
        'type': type,
        'isActive': isActive ? '1' : '0',
        'sortOrder': sortOrder.toString(),
      },
    );
    return LogisticsProvider.fromJson(response);
  }

  Future<LogisticsProvider> update(
    int id, {
    required String name,
    String? description,
    required String type,
    bool isActive = true,
    int sortOrder = 0,
    Uint8List? imageBytes,
  }) async {
    final response = await _multipartRequest(
      method: 'PUT',
      path: '/logistics-provider/$id',
      imageBytes: imageBytes,
      fields: {
        'name': name,
        'description': description ?? '',
        'type': type,
        'isActive': isActive ? '1' : '0',
        'sortOrder': sortOrder.toString(),
      },
    );
    return LogisticsProvider.fromJson(response);
  }

  Future<void> toggleActive(int id) async {
    await _api.patch('/logistics-provider/$id/toggle-active', {}, auth: true);
  }

  Future<void> delete(int id) async {
    await _api.delete('/logistics-provider/$id', auth: true);
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
        http.MultipartFile.fromBytes('file', imageBytes, filename: 'logo.jpg'),
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
