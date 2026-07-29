import '../models/product.dart';
import 'api_client.dart';

class ProductService {
  final ApiClient _api = ApiClient();

  Future<List<Product>> getProducts({
    int? categoryId,
    int? storeId,
    String? search,
    bool includeHidden = false,
  }) async {
    final params = <String>[];
    if (categoryId != null) params.add('categoryId=$categoryId');
    if (storeId != null) params.add('storeId=$storeId');
    if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeComponent(search)}');
    if (includeHidden) params.add('includeHidden=true');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';

    final json = await _api.get('/products$query', auth: includeHidden);
    final items = json['items'] as List<dynamic>? ?? [];
    return items.map((e) => Product.fromJson(e)).toList();
  }

  Future<Product> getProduct(int id) async {
    final json = await _api.get('/products/$id');
    return Product.fromJson(json);
  }

  Future<Product> createProduct({
    required int storeId,
    required int categoryId,
    required int unitId,
    required String nameLao,
    String? nameEn,
    String? description,
    required double basePrice,
    double stockQty = 0,
  }) async {
    final json = await _api.post('/products/store/$storeId', {
      'categoryId': categoryId,
      'unitId': unitId,
      'nameLao': nameLao,
      if (nameEn != null) 'nameEn': nameEn,
      if (description != null) 'description': description,
      'basePrice': basePrice,
      'stockQty': stockQty,
    }, auth: true);
    return Product.fromJson(json);
  }

  /// Edits a product's fields, and/or toggles visibility (isActive).
  /// Only non-null fields are sent.
  Future<Product> updateProduct(
    int id, {
    int? categoryId,
    int? unitId,
    String? nameLao,
    String? nameEn,
    String? description,
    double? basePrice,
    double? stockQty,
    bool? isActive,
  }) async {
    final json = await _api.patch('/products/$id', {
      if (categoryId != null) 'categoryId': categoryId,
      if (unitId != null) 'unitId': unitId,
      if (nameLao != null) 'nameLao': nameLao,
      if (nameEn != null) 'nameEn': nameEn,
      if (description != null) 'description': description,
      if (basePrice != null) 'basePrice': basePrice,
      if (stockQty != null) 'stockQty': stockQty,
      if (isActive != null) 'isActive': isActive ? 1 : 0,
    }, auth: true);
    return Product.fromJson(json);
  }
}
