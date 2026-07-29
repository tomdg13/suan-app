import '../models/admin_user.dart';
import 'api_client.dart';

/// Admin-only user management (requires an admin-role account —
/// backend rejects with 403 otherwise).
class UserService {
  final ApiClient _api = ApiClient();

  Future<List<AdminUser>> getAllUsers() async {
    final json = await _api.get('/users', auth: true);
    return (json as List).map((e) => AdminUser.fromJson(e)).toList();
  }

  Future<AdminUser> updateRole(int userId, String role) async {
    final json = await _api.patch('/users/$userId', {'role': role}, auth: true);
    return AdminUser.fromJson(json);
  }

  Future<AdminUser> setActive(int userId, bool active) async {
    final json = await _api.patch('/users/$userId', {'isActive': active ? 1 : 0}, auth: true);
    return AdminUser.fromJson(json);
  }

  /// Full profile update — name, phone, email. Only non-null fields are sent.
  Future<AdminUser> updateProfile(
    int userId, {
    String? fullName,
    String? phone,
    String? email,
  }) async {
    final json = await _api.patch('/users/$userId', {
      if (fullName != null) 'fullName': fullName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
    }, auth: true);
    return AdminUser.fromJson(json);
  }
}
