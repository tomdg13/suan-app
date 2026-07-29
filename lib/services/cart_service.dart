import '../models/cart_item.dart';
import 'api_client.dart';

class CartService {
  final ApiClient _api = ApiClient();

  Future<void> addToCart({required int productId, int? variantId, required double qty}) async {
    await _api.post('/cart', {
      'productId': productId,
      if (variantId != null) 'variantId': variantId,
      'qty': qty,
    }, auth: true);
  }

  Future<List<CartGroup>> getCart() async {
    final json = await _api.get('/cart', auth: true);
    return (json as List).map((e) => CartGroup.fromJson(e)).toList();
  }

  Future<void> updateQty(int itemId, double qty) async {
    await _api.patch('/cart/$itemId', {'qty': qty}, auth: true);
  }

  Future<void> removeItem(int itemId) async {
    await _api.delete('/cart/$itemId', auth: true);
  }
}
