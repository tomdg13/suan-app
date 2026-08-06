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

class OrdersService {
  final ApiClient _api = ApiClient();

  /// Creates the order from the buyer's current cart.
  /// Matches POST /orders/checkout (CheckoutDto: addressId, paymentMethod?, promotionId?)
  Future<Map<String, dynamic>> checkout({
    required int addressId,
    PaymentMethod? paymentMethod,
    int? promotionId,
  }) async {
    final json = await _api.post(
      '/orders/checkout',
      {
        'addressId': addressId,
        if (paymentMethod != null) 'paymentMethod': paymentMethod.apiValue,
        if (promotionId != null) 'promotionId': promotionId,
      },
      auth: true,
    );
    return json as Map<String, dynamic>;
  }
}
