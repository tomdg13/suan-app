class OrderItemModel {
  final int id;
  final String itemName;
  final String? variantLabel;
  final double qty;
  final double unitPrice;
  final double subtotal;
  final String? imageUrl;

  OrderItemModel({
    required this.id,
    required this.itemName,
    this.variantLabel,
    required this.qty,
    required this.unitPrice,
    required this.subtotal,
    this.imageUrl,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    // Product images come back nested as items.product.images (list),
    // ordered by sortOrder on the backend — just take the first one.
    final images = json['product']?['images'] as List<dynamic>?;
    final firstImage = (images != null && images.isNotEmpty) ? images.first : null;

    return OrderItemModel(
      id: json['id'],
      itemName: json['itemName'] ?? '',
      variantLabel: json['variantLabel'],
      qty: double.tryParse('${json['qty']}') ?? 0,
      unitPrice: double.tryParse('${json['unitPrice']}') ?? 0,
      subtotal: double.tryParse('${json['subtotal']}') ?? 0,
      imageUrl: firstImage?['imageUrl'],
    );
  }
}

class OrderModel {
  final int id;
  final String orderCode;
  final String status;
  final String paymentStatus;
  final double totalAmount;
  final DateTime orderDate;
  final String? storeName;
  final String? paymentProofUrl;
  final String? rrn;
  final String? buyerName;
  final String? buyerPhone;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.orderCode,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    required this.orderDate,
    this.storeName,
    this.paymentProofUrl,
    this.rrn,
    this.buyerName,
    this.buyerPhone,
    this.items = const [],
  });

  /// True once the buyer has uploaded a screenshot + RRN, even before an
  /// admin has confirmed it. Used to distinguish "hasn't paid at all" from
  /// "paid and waiting on confirmation" — both are paymentStatus: unpaid
  /// on the backend since there's no separate pending-confirmation state.
  bool get proofSubmitted => paymentProofUrl != null && paymentProofUrl!.isNotEmpty;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      orderCode: json['orderCode'] ?? '',
      status: json['status'] ?? 'pending',
      paymentStatus: json['paymentStatus'] ?? 'unpaid',
      totalAmount: double.tryParse('${json['totalAmount']}') ?? 0,
      orderDate: DateTime.tryParse(json['orderDate'] ?? '') ?? DateTime.now(),
      storeName: json['store']?['storeName'],
      paymentProofUrl: json['paymentProofUrl'],
      rrn: json['rrn'],
      buyerName: json['user']?['fullName'],
      buyerPhone: json['user']?['phone'],
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => OrderItemModel.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}
