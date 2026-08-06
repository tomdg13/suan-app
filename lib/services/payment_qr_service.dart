import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Handles reading/writing the admin's payment QR (e.g. PromptPay / bank
/// transfer QR shown to buyers/sellers on withdrawal or payment screens).
///
/// TODO: point `_baseUrl` at your real API host, and swap the auth header
/// below for however the rest of the app attaches the session/admin token
/// (e.g. read it off `AppState` and pass it in, or use an existing
/// `ApiClient`/`Dio` instance if the project already has one).
class PaymentQrService {
  PaymentQrService({this.authToken});

  final String? authToken;

  static const String _baseUrl = 'https://YOUR_API_HOST/api';

  Map<String, String> get _headers => {
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  /// Uploads a new payment QR image from raw bytes (works on Web, mobile,
  /// and desktop — unlike `MultipartFile.fromPath`, which needs a real
  /// filesystem path and fails on Flutter Web). Returns the public URL of
  /// the uploaded QR on success.
  Future<String> uploadQr(Uint8List imageBytes, String filename) async {
    final uri = Uri.parse('$_baseUrl/admin/payment-qr');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers)
      ..files.add(
        http.MultipartFile.fromBytes('qr_image', imageBytes, filename: filename),
      );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to upload QR (${response.statusCode}): ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    // Adjust this key to match whatever your backend actually returns.
    final url = body['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Upload succeeded but no QR URL was returned.');
    }
    return url;
  }

  /// Fetches the currently active payment QR URL, if one has been set.
  Future<String?> fetchCurrentQr() async {
    final uri = Uri.parse('$_baseUrl/admin/payment-qr');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Failed to load current QR (${response.statusCode}): ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['url'] as String?;
  }
}
