class AdminUser {
  final int id;
  final String fullName;
  final String phone;
  final String? email;
  final String role;
  final int isActive;

  AdminUser({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    required this.role,
    required this.isActive,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'],
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'buyer',
      isActive: json['isActive'] ?? 1,
    );
  }
}
