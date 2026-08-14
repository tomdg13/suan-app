import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../services/api_client.dart';
import '../admin/admin_shell_screen.dart';
import '../seller/seller_shell_screen.dart';
import 'register_screen.dart';

/// Keeps the phone field locked to the "20" prefix — the person can only
/// type/delete the 8 digits after it, never the prefix itself.
class _PhonePrefixFormatter extends TextInputFormatter {
  static const _prefix = '20';

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (!text.startsWith(_prefix)) {
      // Person tried to delete/alter the prefix — snap back to it.
      text = _prefix + text.replaceFirst(_prefix, '');
      if (!text.startsWith(_prefix)) text = _prefix;
    }
    // Digits only, capped at 10 total (prefix + 8).
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digitsOnly.length > 10 ? digitsOnly.substring(0, 10) : digitsOnly;
    final selectionIndex = capped.length;
    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController(text: '20');
  final _passwordCtrl = TextEditingController();
  String? _error;

  /// Lao mobile numbers used for login must start with "20" and be
  /// exactly 10 digits total (e.g. 2022222223).
  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'ກະລຸນາປ້ອນເບີໂທ';
    if (!RegExp(r'^20\d{8}$').hasMatch(v)) {
      return 'ເບີໂທຕ້ອງເລີ່ມຕົ້ນດ້ວຍ 20 ແລະ ມີ 10 ໂຕເລກ (ຕົວຢ່າງ 2022222223)';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
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
      appBar: AppBar(title: const Text('ເຂົ້າສູ່ລະບົບ')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront, size: 64, color: Colors.green),
                  const SizedBox(height: 8),
                  const Text('ສວນມັງກອມ',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [_PhonePrefixFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'ເບີໂທ',
                      hintText: '20XXXXXXXX',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'ລະຫັດຜ່ານ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'ກະລຸນາປ້ອນລະຫັດຜ່ານ' : null,
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
                          : const Text('ເຂົ້າສູ່ລະບົບ'),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text('ຍັງບໍ່ມີບັນຊີ? ລົງທະບຽນ'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
