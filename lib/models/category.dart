// lib/models/category.dart
class ProductCategory {
  final int id;
  final String nameLao;
  final String? nameEn;
  final String? iconUrl;
  final int sortOrder;
  final bool isActive;

  ProductCategory({
    required this.id,
    required this.nameLao,
    this.nameEn,
    this.iconUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'],
      nameLao: json['nameLao'] ?? '',
      nameEn: json['nameEn'],
      iconUrl: json['iconUrl'],
      sortOrder: json['sortOrder'] ?? 0,
      isActive: (json['isActive'] ?? 1) == 1,
    );
  }
}
