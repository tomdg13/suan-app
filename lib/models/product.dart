class ProductVariant {
  final int id;
  final String variantLabel;
  final double price;
  final double stockQty;

  ProductVariant({
    required this.id,
    required this.variantLabel,
    required this.price,
    required this.stockQty,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'],
      variantLabel: json['variantLabel'] ?? '',
      price: double.tryParse('${json['price']}') ?? 0,
      stockQty: double.tryParse('${json['stockQty']}') ?? 0,
    );
  }
}

class ProductImageInfo {
  final int id;
  final String imageUrl;

  ProductImageInfo({required this.id, required this.imageUrl});

  factory ProductImageInfo.fromJson(Map<String, dynamic> json) {
    return ProductImageInfo(
      id: json['id'],
      imageUrl: json['imageUrl'] ?? '',
    );
  }
}

class Product {
  final int id;
  final int storeId;
  final int categoryId;
  final int unitId;
  final String nameLao;
  final String? nameEn;
  final String? description;
  final double basePrice;
  final double stockQty;
  final int soldCount;
  final double ratingAvg;
  final int ratingCount;
  final List<ProductVariant> variants;
  final List<ProductImageInfo> images;
  final String? storeName;
  final bool isActive;
  final bool isFlashSale;

  Product({
    required this.id,
    required this.storeId,
    required this.categoryId,
    required this.unitId,
    required this.nameLao,
    this.nameEn,
    this.description,
    required this.basePrice,
    required this.stockQty,
    this.soldCount = 0,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.variants = const [],
    this.images = const [],
    this.storeName,
    this.isActive = true,
    this.isFlashSale = false,
  });

  /// Convenience list of just the URLs, for screens that don't need
  /// each image's ID (product cards, product detail gallery, etc.)
  List<String> get imageUrls => images.map((e) => e.imageUrl).toList();

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      storeId: json['storeId'] ?? (json['store']?['id'] ?? 0),
      categoryId: json['categoryId'] ?? (json['category']?['id'] ?? 0),
      unitId: json['unitId'] ?? (json['unit']?['id'] ?? 0),
      nameLao: json['nameLao'] ?? '',
      nameEn: json['nameEn'],
      description: json['description'],
      basePrice: double.tryParse('${json['basePrice']}') ?? 0,
      stockQty: double.tryParse('${json['stockQty']}') ?? 0,
      soldCount: json['soldCount'] ?? 0,
      ratingAvg: double.tryParse('${json['ratingAvg']}') ?? 0,
      ratingCount: json['ratingCount'] ?? 0,
      variants: (json['variants'] as List<dynamic>? ?? [])
          .map((v) => ProductVariant.fromJson(v))
          .toList(),
      images: (json['images'] as List<dynamic>? ?? [])
          .map((img) => ProductImageInfo.fromJson(img))
          .toList(),
      storeName: json['store']?['storeName'],
      isActive: json['isActive'] == 1 || json['isActive'] == true,
      isFlashSale: json['isFlashSale'] == 1 || json['isFlashSale'] == true,
    );
  }
}
