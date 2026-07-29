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
}
