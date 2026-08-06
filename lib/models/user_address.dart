class UserAddress {
  final int id;
  final String label;
  final String recipientName;
  final String phone;
  final String addressLine;
  final String? village;
  final String? district;
  final String? province;
  final bool isDefault;

  UserAddress({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.addressLine,
    this.village,
    this.district,
    this.province,
    required this.isDefault,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['id'] as int,
      label: (json['label'] as String?) ?? 'home',
      recipientName: json['recipientName'] as String,
      phone: json['phone'] as String,
      addressLine: json['addressLine'] as String,
      village: json['village'] as String?,
      district: json['district'] as String?,
      province: json['province'] as String?,
      isDefault: (json['isDefault'] as int? ?? 0) == 1,
    );
  }

  /// One-line display, e.g. "123 Main Rd, Sikhottabong, Vientiane"
  String get shortDisplay {
    final parts = [addressLine, village, district, province]
        .where((p) => p != null && p.isNotEmpty)
        .join(', ');
    return parts;
  }
}
