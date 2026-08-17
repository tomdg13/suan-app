import '../models/product.dart';
import '../models/product_stock_log.dart';
import 'api_client.dart';

class ProductPage {
  final List<Product> items;
  final int total;
  final int page;
  final int limit;
  ProductPage({required this.items, required this.total, required this.page, required this.limit});
}

class ProductService {
  final ApiClient _api = ApiClient();

  Future<ProductPage> getProductsPaged({
    int? categoryId,
    int? storeId,
    String? search,
    bool includeHidden = false,
    int page = 1,
    int limit = 10,
  }) async {
    final params = <String>[];
    if (categoryId != null) params.add('categoryId=$categoryId');
    if (storeId != null) params.add('storeId=$storeId');
    if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeComponent(search)}');
    if (includeHidden) params.add('includeHidden=true');
    params.add('page=$page');
    params.add('limit=$limit');
    final query = '?${params.join('&')}';
    final json = await _api.get('/products$query', auth: includeHidden);
    final items = (json['items'] as List<dynamic>? ?? []).map((e) => Product.fromJson(e)).toList();
    return ProductPage(
      items: items,
      total: json['total'] as int? ?? items.length,
      page: json['page'] as int? ?? page,
      limit: json['limit'] as int? ?? limit,
    );
  }

  Future<List<Product>> getProducts({
    int? categoryId,
    int? storeId,
    String? search,
    bool includeHidden = false,
    int? limit,
  }) async {
    final params = <String>[];
    if (categoryId != null) params.add('categoryId=$categoryId');
    if (storeId != null) params.add('storeId=$storeId');
    if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeComponent(search)}');
    if (includeHidden) params.add('includeHidden=true');
    if (limit != null) params.add('limit=$limit');
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
    double weight = 0,
  }) async {
    final json = await _api.post('/products/store/$storeId', {
      'categoryId': categoryId,
      'unitId': unitId,
      'nameLao': nameLao,
      if (nameEn != null) 'nameEn': nameEn,
      if (description != null) 'description': description,
      'basePrice': basePrice,
      'stockQty': stockQty,
      'weight': weight,
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
    double? weight,
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
      if (weight != null) 'weight': weight,
      if (isActive != null) 'isActive': isActive ? 1 : 0,
    }, auth: true);
    return Product.fromJson(json);
  }

  /// Stock movement history for a product — newest first. Matches
  /// GET /products/:id/stock-history.
  Future<List<ProductStockLogEntry>> getStockHistory(int productId) async {
    final json = await _api.get('/products/$productId/stock-history', auth: true);
    return (json as List).map((e) => ProductStockLogEntry.fromJson(e)).toList();
  }

  /// Deletes a product permanently. Backend blocks this (400) if the
  /// product has past orders referencing it — hide it via updateProduct
  /// (isActive: false) instead in that case.
  Future<void> deleteProduct(int id) async {
    await _api.delete('/products/$id', auth: true);
  }
}
