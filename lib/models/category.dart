class ProductCategory {
  final int id;
  final String nameLao;
  final String? nameEn;
  final String? iconUrl;

  ProductCategory({
    required this.id,
    required this.nameLao,
    this.nameEn,
    this.iconUrl,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'],
      nameLao: json['nameLao'] ?? '',
      nameEn: json['nameEn'],
      iconUrl: json['iconUrl'],
    );
  }
}
