class ProductStockLogEntry {
  final int id;
  final double delta;
  final double resultingStock;
  final int? changedBy;
  final String? note;
  final DateTime createdAt;

  ProductStockLogEntry({
    required this.id,
    required this.delta,
    required this.resultingStock,
    this.changedBy,
    this.note,
    required this.createdAt,
  });

  factory ProductStockLogEntry.fromJson(Map<String, dynamic> json) {
    return ProductStockLogEntry(
      id: json['id'],
      delta: double.tryParse('${json['delta']}') ?? 0,
      resultingStock: double.tryParse('${json['resultingStock']}') ?? 0,
      changedBy: json['changedBy'],
      note: json['note'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
