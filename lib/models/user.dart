class AppUser {
  final int id;
  final String fullName;
  final String phone;
  final String role; // buyer, seller, admin

  AppUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'buyer',
    );
  }
}
