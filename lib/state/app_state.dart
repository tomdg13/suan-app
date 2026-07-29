import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AppState extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? currentUser;
  bool isLoading = false;

  // True while checking for a saved session on app startup. The UI
  // should show a splash/loading state until this resolves, otherwise
  // it'll briefly flash "logged out" before the saved token loads.
  bool isRestoringSession = true;

  bool get isLoggedIn => currentUser != null;

  /// Call once on app startup. Checks for a saved token and, if valid,
  /// restores the logged-in session without the person re-entering
  /// their password — this is what makes login "stick" across app
  /// restarts, like Facebook/most consumer apps.
  Future<void> restoreSession() async {
    isRestoringSession = true;
    notifyListeners();
    try {
      currentUser = await _authService.restoreSession();
    } finally {
      isRestoringSession = false;
      notifyListeners();
    }
  }

  Future<void> login(String phone, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      currentUser = await _authService.login(phone: phone, password: password);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String fullName, String phone, String password, {String? role}) async {
    isLoading = true;
    notifyListeners();
    try {
      await _authService.register(
        fullName: fullName,
        phone: phone,
        password: password,
        role: role,
      );
      await login(phone, password);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    currentUser = null;
    notifyListeners();
  }
}
