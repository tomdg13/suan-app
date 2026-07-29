class BannerItem {
  final int id;
  final String imageUrl;
  final String? title;
  final String? subtitle;
  final String? linkUrl;
  final int sortOrder;
  final bool isActive;

  BannerItem({
    required this.id,
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.linkUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      id: json['id'],
      imageUrl: json['imageUrl'] ?? '',
      title: json['title'],
      subtitle: json['subtitle'],
      linkUrl: json['linkUrl'],
      sortOrder: json['sortOrder'] ?? 0,
      isActive: json['isActive'] == 1 || json['isActive'] == true,
    );
  }
}
