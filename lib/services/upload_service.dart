import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/store.dart';
import '../models/product.dart';
import 'api_client.dart';

class UploadService {
  final ApiClient _api = ApiClient();

  /// Uploads a store's logo or cover image from raw bytes (post-crop,
  /// post-compression) and returns the updated Store.
  Future<Store> uploadStoreImageBytes({
    required int storeId,
    required String type, // 'logo' or 'cover'
    required Uint8List bytes,
    String filename = 'image.jpg',
  }) async {
    final response = await _multipartUpload(
      path: '/stores/$storeId/$type',
      filesBytes: [bytes],
      fieldName: 'file',
      baseFilename: type,
    );
    return Store.fromJson(response);
  }

  /// Uploads one or more product photos (appends to existing ones) and
  /// returns the updated Product with its full image list.
  Future<Product> uploadProductImages({
    required int productId,
    required List<Uint8List> imagesBytes,
  }) async {
    final response = await _multipartUpload(
      path: '/products/$productId/images',
      filesBytes: imagesBytes,
      fieldName: 'files',
      baseFilename: 'product',
    );
    return Product.fromJson(response);
  }

  /// Deletes a single product image and returns the updated Product.
  Future<Product> deleteProductImage(int imageId) async {
    final token = await _api.getToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}/products/images/$imageId');
    final headers = <String, String>{};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.delete(uri, headers: headers);
    final decoded = _decodeOrThrow(response);
    return Product.fromJson(decoded);
  }

  Future<Map<String, dynamic>> _multipartUpload({
    required String path,
    required List<Uint8List> filesBytes,
    required String fieldName,
    required String baseFilename,
  }) async {
    final token = await _api.getToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    for (var i = 0; i < filesBytes.length; i++) {
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          filesBytes[i],
          filename: '$baseFilename-$i.jpg',
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _decodeOrThrow(response);
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
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
