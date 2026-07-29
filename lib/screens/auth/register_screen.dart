import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../services/api_client.dart';
import '../admin/admin_shell_screen.dart';
import '../seller/seller_shell_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'buyer';
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    final appState = context.read<AppState>();
    try {
      await appState.register(
        _nameCtrl.text.trim(),
        _phoneCtrl.text.trim(),
        _passwordCtrl.text,
        role: _role,
      );
      if (!mounted) return;
      _routeAfterLogin(appState.currentUser?.role);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

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
      // Pop RegisterScreen, then pop the LoginScreen underneath it,
      // returning control (with success=true) to whatever screen
      // originally triggered the login flow.
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Account type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'buyer', child: Text('Buyer')),
                    DropdownMenuItem(value: 'seller', child: Text('Seller')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'buyer'),
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
                        : const Text('Create account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
