class AppUser {
  final int id;
  final String fullName;
  final String phone;
  final String role; // buyer, seller, admin
  final String? avatarUrl;

  AppUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.avatarUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'buyer',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  AppUser copyWith({String? avatarUrl}) {
    return AppUser(
      id: id,
      fullName: fullName,
      phone: phone,
      role: role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
