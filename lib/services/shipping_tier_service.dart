import 'api_client.dart';

class ShippingTier {
  final int id;
  final int? productId;
  final int? providerId;
  final String metric; // 'weight' | 'size'
  final double minWeight;
  final double? maxWeight;
  final int price;
  final int sortOrder;
  final bool isActive;

  ShippingTier({
    required this.id,
    this.productId,
    this.providerId,
    this.metric = 'weight',
    required this.minWeight,
    this.maxWeight,
    required this.price,
    required this.sortOrder,
    required this.isActive,
  });

  factory ShippingTier.fromJson(Map<String, dynamic> json) => ShippingTier(
        id: json['id'] as int,
        productId: json['productId'] as int?,
        providerId: json['providerId'] as int?,
        metric: json['metric'] as String? ?? 'weight',
        minWeight: double.tryParse('${json['minWeight']}') ?? 0,
        maxWeight: json['maxWeight'] == null ? null : double.tryParse('${json['maxWeight']}'),
        price: json['price'] is int ? json['price'] as int : int.tryParse('${json['price']}') ?? 0,
        sortOrder:
            json['sortOrder'] is int ? json['sortOrder'] as int : int.tryParse('${json['sortOrder']}') ?? 0,
        isActive: (json['isActive'] == 1 || json['isActive'] == true),
      );
}

class ShippingTierService {
  ShippingTierService();
  final ApiClient _api = ApiClient();

  /// Public — buyer/cart screens use this for a live fee estimate.
  Future<List<ShippingTier>> fetchActive() async {
    final body = await _api.get('/shipping-tiers/active');
    return (body as List).map((e) => ShippingTier.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Admin — full list (including inactive) for the management screen.
  Future<List<ShippingTier>> fetchAll() async {
    final body = await _api.get('/shipping-tiers', auth: true);
    return (body as List).map((e) => ShippingTier.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Public — a single product's own tiers (seller's product form,
  /// buyer's product detail page).
  Future<List<ShippingTier>> fetchByProduct(int productId) async {
    final body = await _api.get('/shipping-tiers/by-product/$productId');
    return (body as List).map((e) => ShippingTier.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Given a product + its weight (kg) + size (cm), returns the fee.
  /// Matches GET /shipping-tiers/calculate.
  Future<int> calculate({
    required int productId,
    double weightKg = 0,
    double sizeCm = 0,
  }) async {
    final body = await _api.get(
      '/shipping-tiers/calculate?productId=$productId&weight=$weightKg&size=$sizeCm',
    );
    final map = body as Map<String, dynamic>;
    return map['price'] is int ? map['price'] as int : int.tryParse('${map['price']}') ?? 0;
  }

  /// Finds the price for [weightKg]/[sizeCm] from an already-fetched tier
  /// list for ONE product — avoids an extra API round-trip. Mirrors the
  /// backend's calculateFeeForProduct logic (max of weight/size match).
  static int priceForValues(List<ShippingTier> tiers, {double weightKg = 0, double sizeCm = 0}) {
    if (tiers.isEmpty) return 0;
    int? matchMetric(String metric, double value) {
      final filtered = tiers.where((t) => t.metric == metric).toList()
        ..sort((a, b) => a.minWeight.compareTo(b.minWeight));
      if (filtered.isEmpty) return null;
      for (final tier in filtered) {
        final withinMin = value >= tier.minWeight;
        final withinMax = tier.maxWeight == null || value <= tier.maxWeight!;
        if (withinMin && withinMax) return tier.price;
      }
      return filtered.last.price;
    }

    final byWeight = matchMetric('weight', weightKg);
    final bySize = matchMetric('size', sizeCm);
    final candidates = [byWeight, bySize].whereType<int>().toList();
    if (candidates.isEmpty) return 0;
    return candidates.reduce((a, b) => a > b ? a : b);
  }

  Future<ShippingTier> create({
    required int productId,
    required String metric,
    required double minWeight,
    double? maxWeight,
    required int price,
    int sortOrder = 0,
  }) async {
    final body = await _api.post('/shipping-tiers', {
      'productId': productId,
      'metric': metric,
      'minWeight': minWeight,
      if (maxWeight != null) 'maxWeight': maxWeight,
      'price': price,
      'sortOrder': sortOrder,
    }, auth: true);
    return ShippingTier.fromJson(body as Map<String, dynamic>);
  }

  Future<ShippingTier> update(
    int id, {
    int? productId,
    String? metric,
    double? minWeight,
    double? maxWeight,
    int? price,
    int? sortOrder,
  }) async {
    final patch = <String, dynamic>{
      if (productId != null) 'productId': productId,
      if (metric != null) 'metric': metric,
      if (minWeight != null) 'minWeight': minWeight,
      if (maxWeight != null) 'maxWeight': maxWeight,
      if (price != null) 'price': price,
      if (sortOrder != null) 'sortOrder': sortOrder,
    };
    final body = await _api.patch('/shipping-tiers/$id', patch, auth: true);
    return ShippingTier.fromJson(body as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.delete('/shipping-tiers/$id', auth: true);
  }
}
