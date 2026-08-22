import '../models/cart_item.dart';
import 'api_client.dart';

class CartService {
  final ApiClient _api = ApiClient();

  /// Adds to cart (or merges qty into an existing matching row) and
  /// returns the resulting cart item's id, so callers like "buy now"
  /// can link that specific item to later screens (e.g. for the qty
  /// adjuster on the payment page).
  Future<int?> addToCart({required int productId, int? variantId, required double qty}) async {
    final json = await _api.post('/cart', {
      'productId': productId,
      if (variantId != null) 'variantId': variantId,
      'qty': qty,
    }, auth: true);
    return (json as Map<String, dynamic>)['id'] as int?;
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
