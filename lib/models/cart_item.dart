class CartItem {
  final int id;
  final int productId;
  final int? variantId;
  final double qty;
  final String productName;
  final double unitPrice;
  final String? variantLabel;

  CartItem({
    required this.id,
    required this.productId,
    this.variantId,
    required this.qty,
    required this.productName,
    required this.unitPrice,
    this.variantLabel,
  });

  double get subtotal => qty * unitPrice;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] ?? {};
    final variant = json['variant'];
    return CartItem(
      id: json['id'],
      productId: json['productId'],
      variantId: json['variantId'],
      qty: double.tryParse('${json['qty']}') ?? 1,
      productName: product['nameLao'] ?? '',
      unitPrice: variant != null
          ? double.tryParse('${variant['price']}') ?? 0
          : double.tryParse('${product['basePrice']}') ?? 0,
      variantLabel: variant != null ? variant['variantLabel'] : null,
    );
  }
}

class CartGroup {
  final int storeId;
  final String storeName;
  final List<CartItem> items;

  CartGroup({required this.storeId, required this.storeName, required this.items});

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);

  factory CartGroup.fromJson(Map<String, dynamic> json) {
    final store = json['store'] ?? {};
    return CartGroup(
      storeId: store['id'] ?? 0,
      storeName: store['storeName'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => CartItem.fromJson(i))
          .toList(),
    );
  }
}
