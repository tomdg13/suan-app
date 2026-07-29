class OrderModel {
  final int id;
  final String orderCode;
  final String status;
  final String paymentStatus;
  final double totalAmount;
  final DateTime orderDate;
  final String? storeName;

  OrderModel({
    required this.id,
    required this.orderCode,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    required this.orderDate,
    this.storeName,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      orderCode: json['orderCode'] ?? '',
      status: json['status'] ?? 'pending',
      paymentStatus: json['paymentStatus'] ?? 'unpaid',
      totalAmount: double.tryParse('${json['totalAmount']}') ?? 0,
      orderDate: DateTime.tryParse(json['orderDate'] ?? '') ?? DateTime.now(),
      storeName: json['store']?['storeName'],
    );
  }
}
