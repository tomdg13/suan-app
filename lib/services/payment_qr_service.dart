import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import 'api_client.dart';

/// Handles reading/writing the admin's payment QR (e.g. LAPNet/LAO QR Pay)
/// shown to buyers/sellers on payment screens.
///
/// Matches the real backend routes in suan-api's PaymentQrModule:
///   GET    /api/payment-qr          -> current active QR (public, no auth)
///   GET    /api/payment-qr/history  -> admin only
///   GET    /api/payment-qr/:id      -> admin only
///   POST   /api/payment-qr          -> admin only, multipart field "file"
///   PATCH  /api/payment-qr/:id      -> admin only, multipart field "file"
///   DELETE /api/payment-qr/:id      -> admin only
///
/// Uploaded images are served from the backend ROOT (not under /api), so
/// display URLs use ApiConfig.mediaBaseUrl, e.g.
/// https://api.mungkonefarm.com/uploads/payment-qr/xyz.jpg
class PaymentQrService {
  PaymentQrService();

  final ApiClient _api = ApiClient();

  static String get _baseUrl => ApiConfig.baseUrl;

  /// Turns the relative path the backend stores (e.g.
  /// "/uploads/payment-qr/xyz.jpg") into a fully-qualified URL the app
  /// can actually load.
  String _resolveImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    return '${ApiConfig.mediaBaseUrl}$imageUrl';
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _api.getToken();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Uploads a new payment QR image from raw bytes (works on Web, mobile,
  /// and desktop). [title] is optional — the DTO only requires the file.
  /// Returns the public, fully-qualified URL of the uploaded QR.
  Future<String> uploadQr(Uint8List imageBytes, String filename, {String? title}) async {
    final uri = Uri.parse('$_baseUrl/payment-qr');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(await _authHeaders())
      ..files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: filename),
      )
      ..fields.addAll({
        if (title != null && title.isNotEmpty) 'title': title,
      });

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to upload QR (${response.statusCode}): ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final imageUrl = body['imageUrl'] as String?;
    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('Upload succeeded but no QR image URL was returned.');
    }
    return _resolveImageUrl(imageUrl);
  }

  /// Fetches the currently active payment QR URL, if one has been set.
  /// This endpoint is public (no auth guard on the backend).
  Future<String?> fetchCurrentQr() async {
    final uri = Uri.parse('$_baseUrl/payment-qr');
    final response = await http.get(uri);

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Failed to load current QR (${response.statusCode}): ${response.body}');
    }

    final body = jsonDecode(response.body);
    if (body == null) return null;
    final map = body as Map<String, dynamic>;
    final imageUrl = map['imageUrl'] as String?;
    if (imageUrl == null || imageUrl.isEmpty) return null;
    return _resolveImageUrl(imageUrl);
  }
}
