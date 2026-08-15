class Store {
  final int id;
  final int? ownerId;
  final String storeName;
  final String? logoUrl;
  final String? coverUrl;
  final String? province;
  final double ratingAvg;
  final int followerCount;
  final bool isVerified;

  Store({
    required this.id,
    this.ownerId,
    required this.storeName,
    this.logoUrl,
    this.coverUrl,
    this.province,
    this.ratingAvg = 0,
    this.followerCount = 0,
    this.isVerified = false,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'],
      ownerId: json['ownerId'],
      storeName: json['storeName'] ?? '',
      logoUrl: json['logoUrl'],
      coverUrl: json['coverUrl'],
      province: json['province'],
      ratingAvg: double.tryParse('${json['ratingAvg']}') ?? 0,
      followerCount: json['followerCount'] ?? 0,
      isVerified: json['isVerified'] == 1 || json['isVerified'] == true,
    );
  }
}
