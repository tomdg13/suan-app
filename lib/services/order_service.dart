import '../models/order.dart';
import 'api_client.dart';

class OrderService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> checkout({required int addressId, String? paymentMethod}) async {
    final json = await _api.post('/orders/checkout', {
      'addressId': addressId,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
    }, auth: true);
    return json as List<dynamic>;
  }

  Future<List<OrderModel>> getMyOrders() async {
    final json = await _api.get('/orders/my', auth: true);
    return (json as List).map((e) => OrderModel.fromJson(e)).toList();
  }

  Future<List<OrderModel>> getStoreOrders(int storeId) async {
    final json = await _api.get('/orders/store/$storeId', auth: true);
    return (json as List).map((e) => OrderModel.fromJson(e)).toList();
  }

  Future<void> updateStatus(int orderId, String status) async {
    await _api.patch('/orders/$orderId/status', {'status': status}, auth: true);
  }

  /// Admin: orders where the buyer uploaded payment proof but nobody has
  /// confirmed the money actually arrived yet. Matches
  /// GET /orders/admin/pending-payments (admin role required).
  Future<List<OrderModel>> getPendingPaymentConfirmations() async {
    final json = await _api.get('/orders/admin/pending-payments', auth: true);
    return (json as List).map((e) => OrderModel.fromJson(e)).toList();
  }

  /// Admin: confirms the money actually landed — marks paymentStatus
  /// paid and moves the order to confirmed (seller can start packing).
  /// Matches PATCH /orders/:id/confirm-payment.
  Future<void> confirmPayment(int orderId) async {
    await _api.patch('/orders/$orderId/confirm-payment', {}, auth: true);
  }
}
