import 'package:flutter/material.dart';
import '../../services/order_service.dart';
import '../../services/api_client.dart';
import 'my_orders_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _orderService = OrderService();
  final _addressIdCtrl = TextEditingController(text: '1');
  String _paymentMethod = 'cod';
  bool _submitting = false;
  String? _error;

  final _methods = const {
    'cod': 'Cash on delivery (COD)',
    'bcel_one': 'BCEL One',
    'onepay': 'OnePay',
    'visa_mastercard': 'Visa / Mastercard',
    'qr_pay': 'QR Pay',
  };

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final addressId = int.tryParse(_addressIdCtrl.text.trim()) ?? 1;
      await _orderService.checkout(addressId: addressId, paymentMethod: _paymentMethod);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed!')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delivery address', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _addressIdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Address ID',
                helperText: 'Create an address first via the API (user_addresses).',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Payment method', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioGroup<String>(
              groupValue: _paymentMethod,
              onChanged: (v) => setState(() => _paymentMethod = v!),
              child: Column(
                children: _methods.entries
                    .map((e) => RadioListTile<String>(
                          value: e.key,
                          title: Text(e.value),
                        ))
                    .toList(),
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
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Place order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
