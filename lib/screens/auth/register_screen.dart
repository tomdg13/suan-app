import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../services/api_client.dart';
import '../admin/admin_shell_screen.dart';
import '../seller/seller_shell_screen.dart';

/// Keeps the phone field locked to the "20" prefix — the person can only
/// type/delete the 8 digits after it, never the prefix itself.
class _PhonePrefixFormatter extends TextInputFormatter {
  static const _prefix = '20';

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (!text.startsWith(_prefix)) {
      text = _prefix + text.replaceFirst(_prefix, '');
      if (!text.startsWith(_prefix)) text = _prefix;
    }
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digitsOnly.length > 10 ? digitsOnly.substring(0, 10) : digitsOnly;
    final selectionIndex = capped.length;
    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '20');
  final _passwordCtrl = TextEditingController();
  String _role = 'buyer';
  String? _error;

  /// Lao mobile numbers used for registration must start with "20" and
  /// be exactly 10 digits total (e.g. 2022222223).
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
      appBar: AppBar(title: const Text('ລົງທະບຽນ')),
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
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'ຊື່ເຕັມ', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'ກະລຸນາປ້ອນຊື່' : null,
                  ),
                  const SizedBox(height: 12),
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
                    decoration: const InputDecoration(labelText: 'ລະຫັດຜ່ານ', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty) ? 'ກະລຸນາປ້ອນລະຫັດຜ່ານ' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'ປະເພດບັນຊີ', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'buyer', child: Text('ຜູ້ຊື້')),
                      DropdownMenuItem(value: 'seller', child: Text('ຜູ້ຂາຍ')),
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
                          : const Text('ສ້າງບັນຊີ'),
                    ),
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
