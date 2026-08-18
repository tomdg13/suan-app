import 'api_client.dart';

class ShippingTier {
  final int id;
  final double minWeight;
  final double? maxWeight;
  final int price;
  final int sortOrder;
  final bool isActive;

  ShippingTier({
    required this.id,
    required this.minWeight,
    this.maxWeight,
    required this.price,
    required this.sortOrder,
    required this.isActive,
  });

  factory ShippingTier.fromJson(Map<String, dynamic> json) => ShippingTier(
        id: json['id'] as int,
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

  /// Given a total cart weight (kg), returns the matching tier's price.
  /// Matches GET /shipping-tiers/calculate.
  Future<int> calculate(double weightKg) async {
    final body = await _api.get('/shipping-tiers/calculate?weight=$weightKg');
    final map = body as Map<String, dynamic>;
    return map['price'] is int ? map['price'] as int : int.tryParse('${map['price']}') ?? 0;
  }

  /// Finds the price for [weightKg] from an already-fetched tier list —
  /// avoids an extra API round-trip when the cart screen already has the
  /// active tiers loaded. Mirrors the backend's calculateFee logic exactly.
  static int priceForWeight(List<ShippingTier> tiers, double weightKg) {
    if (tiers.isEmpty) return 0;
    final sorted = [...tiers]..sort((a, b) => a.minWeight.compareTo(b.minWeight));
    for (final tier in sorted) {
      final withinMin = weightKg >= tier.minWeight;
      final withinMax = tier.maxWeight == null || weightKg <= tier.maxWeight!;
      if (withinMin && withinMax) return tier.price;
    }
    return sorted.last.price;
  }

  Future<ShippingTier> create({
    required double minWeight,
    double? maxWeight,
    required int price,
    int sortOrder = 0,
  }) async {
    final body = await _api.post('/shipping-tiers', {
      'minWeight': minWeight,
      if (maxWeight != null) 'maxWeight': maxWeight,
      'price': price,
      'sortOrder': sortOrder,
    }, auth: true);
    return ShippingTier.fromJson(body as Map<String, dynamic>);
  }

  Future<ShippingTier> update(
    int id, {
    double? minWeight,
    double? maxWeight,
    int? price,
    int? sortOrder,
  }) async {
    final patch = <String, dynamic>{
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
