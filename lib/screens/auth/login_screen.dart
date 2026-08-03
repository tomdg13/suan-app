import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../services/api_client.dart';
import '../admin/admin_shell_screen.dart';
import '../seller/seller_shell_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    final appState = context.read<AppState>();
    try {
      await appState.login(_phoneCtrl.text.trim(), _passwordCtrl.text);
      if (!mounted) return;
      _routeAfterLogin(appState.currentUser?.role);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  /// Routes based on account role after a successful login:
  /// - admin  -> Admin Dashboard (replaces this screen)
  /// - seller -> Seller Panel (replaces this screen)
  /// - buyer  -> pops back to wherever login was triggered from
  ///             (e.g. product detail screen, so "Add to cart" can
  ///             continue right where the person left off)
  void _routeAfterLogin(String? role) {
    if (role == 'admin') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminShellScreen()),
      );
    } else if (role == 'seller') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SellerShellScreen()),
      );
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront, size: 64, color: Colors.green),
                const SizedBox(height: 8),
                const Text('ສວນມັງກອມ',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: appState.isLoading ? null : _submit,
                    child: appState.isLoading
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Login'),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: const Text('No account yet? Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
