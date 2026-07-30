class Review {
  final int id;
  final int rating;
  final String? comment;
  final String? userName;
  final String? productName;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.rating,
    this.comment,
    this.userName,
    this.productName,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      userName: json['user']?['fullName'],
      productName: json['product']?['nameLao'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
