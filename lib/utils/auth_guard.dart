import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../screens/auth/login_screen.dart';

/// Call this before any "must be logged in" action (add to cart, checkout,
/// viewing cart/orders, opening seller/admin areas). If the user is already
/// logged in, resolves immediately with true. Otherwise pushes the login
/// screen and waits for the result — true if they successfully logged in,
/// false if they backed out.
Future<bool> ensureLoggedIn(BuildContext context) async {
  final appState = context.read<AppState>();
  if (appState.isLoggedIn) return true;

  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );
  return result == true;
}
