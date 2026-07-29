class ProductUnit {
  final int id;
  final String code;
  final String nameLao;
  final String nameEn;

  ProductUnit({
    required this.id,
    required this.code,
    required this.nameLao,
    required this.nameEn,
  });

  factory ProductUnit.fromJson(Map<String, dynamic> json) {
    return ProductUnit(
      id: json['id'],
      code: json['code'] ?? '',
      nameLao: json['nameLao'] ?? '',
      nameEn: json['nameEn'] ?? '',
    );
  }
}
