import '../config/constants.dart';
import 'api_client.dart';

// ---------------------------------------------------------------------
// PaymentService
//
// Talks to the backend to (1) create a QR payment for an order and
// (2) poll the transaction status until the bank/switch confirms it
// and returns the RRN (Retrieval Reference Number).
//
// Uses the shared ApiClient (same one AuthService/CartService use) so
// auth headers and base URL are handled consistently across the app.
//
// TODO: point these at your real NestJS endpoints, e.g.:
//   POST {ApiConfig.baseUrl}/payments/qr        { orderId, amount }
//   GET  {ApiConfig.baseUrl}/payments/:txnId/status
//
// Adjust field names below (transactionId, qrPayload, qrImageUrl, rrn,
// paidAt) to match whatever your backend actually returns.
// ---------------------------------------------------------------------

class QrPaymentResult {
  final String transactionId;
  final String? qrPayload; // raw EMV/QR30 string, rendered client-side
  final String? qrImageUrl; // OR a pre-rendered QR image from the backend

  QrPaymentResult({
    required this.transactionId,
    this.qrPayload,
    this.qrImageUrl,
  });

  factory QrPaymentResult.fromJson(Map<String, dynamic> json) {
    return QrPaymentResult(
      transactionId: json['transactionId'].toString(),
      qrPayload: json['qrPayload'] as String?,
      qrImageUrl: json['qrImageUrl'] as String?,
    );
  }
}

class PaymentStatusResult {
  final String status; // 'pending' | 'success' | 'failed'
  final String? rrn;
  final DateTime? paidAt;

  PaymentStatusResult({
    required this.status,
    this.rrn,
    this.paidAt,
  });

  factory PaymentStatusResult.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResult(
      status: json['status'] as String,
      rrn: json['rrn'] as String?,
      paidAt: json['paidAt'] != null ? DateTime.tryParse(json['paidAt'] as String) : null,
    );
  }
}

class PaymentService {
  final ApiClient _api = ApiClient();

  Future<QrPaymentResult> createQrPayment({
    required int orderId,
    required double amount,
  }) async {
    final json = await _api.post(
      '/payments/qr',
      {
        'orderId': orderId,
        'amount': amount,
      },
      auth: true,
    );
    return QrPaymentResult.fromJson(json);
  }

  Future<PaymentStatusResult> checkPaymentStatus({
    required String transactionId,
  }) async {
    final json = await _api.get(
      '/payments/$transactionId/status',
      auth: true,
    );
    return PaymentStatusResult.fromJson(json);
  }
}
