import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import 'api_client.dart';

/// Matches suan-api's PaymentMethod enum exactly (order.entity.ts).
enum PaymentMethod { bcelOne, onepay, visaMastercard, qrPay, cod }

extension PaymentMethodValue on PaymentMethod {
  String get apiValue {
    switch (this) {
      case PaymentMethod.bcelOne:
        return 'bcel_one';
      case PaymentMethod.onepay:
        return 'onepay';
      case PaymentMethod.visaMastercard:
        return 'visa_mastercard';
      case PaymentMethod.qrPay:
        return 'qr_pay';
      case PaymentMethod.cod:
        return 'cod';
    }
  }
}

/// Matches suan-api's orders.delivery_method column: enum('delivery','pickup').
enum DeliveryMethod { delivery, pickup }

extension DeliveryMethodValue on DeliveryMethod {
  String get apiValue {
    switch (this) {
      case DeliveryMethod.delivery:
        return 'delivery';
      case DeliveryMethod.pickup:
        return 'pickup';
    }
  }
}

class OrdersService {
  final ApiClient _api = ApiClient();

  /// Creates the order from the buyer's current cart.
  /// Matches POST /orders/checkout (CheckoutDto: addressId, paymentMethod?,
  /// promotionId?, deliveryMethod?, courierName?)
  ///
  /// [courierName] is only meaningful when [deliveryMethod] is
  /// DeliveryMethod.delivery — e.g. "Anousith Logistic". Ignored/sent as
  /// null for pickup orders.
  Future<dynamic> checkout({
    required int addressId,
    PaymentMethod? paymentMethod,
    int? promotionId,
    DeliveryMethod deliveryMethod = DeliveryMethod.delivery,
    String? courierName,
    int? providerId,
  }) async {
    final json = await _api.post(
      '/orders/checkout',
      {
        'addressId': addressId,
        if (paymentMethod != null) 'paymentMethod': paymentMethod.apiValue,
        if (promotionId != null) 'promotionId': promotionId,
        'deliveryMethod': deliveryMethod.apiValue,
        if (deliveryMethod == DeliveryMethod.delivery && courierName != null && courierName.isNotEmpty)
          'courierName': courierName,
        if (providerId != null) 'providerId': providerId,
      },
      auth: true,
    );
    return json; // backend returns a LIST — one order per store in the cart
  }

  /// Uploads the buyer's bank payment-confirmation screenshot + the RRN
  /// they read off it. Matches POST /orders/:id/payment-proof
  /// (multipart field "file", plus a "rrn" text field).
  Future<Map<String, dynamic>> submitPaymentProof({
    required int orderId,
    required Uint8List imageBytes,
    required String filename,
    required String rrn,
  }) async {
    final token = await _api.getToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/payment-proof');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        if (token != null) 'Authorization': 'Bearer $token',
      })
      ..fields['rrn'] = rrn
      ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: filename));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to submit payment proof (${response.statusCode}): ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Server-side OCR (tesseract.js) fallback for platforms without
  /// on-device OCR (Flutter Web — google_mlkit has no web implementation).
  /// Matches POST /orders/ocr-scan (multipart field "file").
  Future<Map<String, dynamic>> ocrScan({
    required Uint8List imageBytes,
    required String filename,
  }) async {
    final token = await _api.getToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/ocr-scan');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        if (token != null) 'Authorization': 'Bearer $token',
      })
      ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: filename));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('OCR scan failed (${response.statusCode}): ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
