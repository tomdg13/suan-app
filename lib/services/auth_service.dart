import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _api = ApiClient();

  Future<AppUser> register({
    required String fullName,
    required String phone,
    required String password,
    String? role,
  }) async {
    final json = await _api.post('/users', {
      'fullName': fullName,
      'phone': phone,
      'password': password,
      if (role != null) 'role': role,
    });
    return AppUser.fromJson(json);
  }

  Future<AppUser> login({required String phone, required String password}) async {
    final json = await _api.post('/auth/login', {
      'phone': phone,
      'password': password,
    });
    await _api.saveToken(json['accessToken']);
    return AppUser.fromJson(json['user']);
  }

  /// Used on app startup: if a token is saved, verifies it's still
  /// valid and fetches the current profile. Returns null if there's
  /// no token, or if the token has expired/is invalid (in which case
  /// the saved token is also cleared).
  Future<AppUser?> restoreSession() async {
    final token = await _api.getToken();
    if (token == null) return null;

    try {
      final json = await _api.get('/auth/me', auth: true);
      return AppUser.fromJson(json);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _api.clearToken();
      }
      return null;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
  }

  Future<bool> isLoggedIn() async {
    final token = await _api.getToken();
    return token != null;
  }
}
