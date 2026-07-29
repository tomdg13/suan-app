import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/cart_item.dart';
import '../../services/cart_service.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cartService = CartService();
  List<CartGroup> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final groups = await _cartService.getCart();
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  double get _grandTotal => _groups.fold(0, (sum, g) => sum + g.subtotal);

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.decimalPattern('en_US');

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? const Center(child: Text('Your cart is empty'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: _groups.map((group) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.storefront, size: 18, color: Colors.green),
                                  const SizedBox(width: 6),
                                  Text(group.storeName,
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Divider(),
                              ...group.items.map((item) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(item.productName),
                                    subtitle: Text(
                                      '${item.variantLabel ?? ''}  x${item.qty.toStringAsFixed(0)}',
                                    ),
                                    trailing: Text(
                                      '${priceFormat.format(item.subtotal)} ກີບ',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  )),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Subtotal: ${priceFormat.format(group.subtotal)} ກີບ',
                                  style: const TextStyle(color: Colors.orange),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
      bottomNavigationBar: _groups.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total: ${priceFormat.format(_grandTotal)} ກີບ',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                        );
                      },
                      child: const Text('Checkout'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
