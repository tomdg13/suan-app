import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../models/cart_item.dart';
import '../../services/cart_service.dart';
import 'buyer_payment_screen.dart';

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

  double get _itemsTotal => _groups.fold(0, (sum, g) => sum + g.subtotal);
  // Backend charges a flat 20,000 ກີບ delivery fee PER STORE in the cart
  // (DEFAULT_DELIVERY_FEE in orders.service.ts) — reflect that here so
  // what's shown matches what checkout will actually charge.
  double get _estimatedDeliveryFee => _groups.length * 20000;
  double get _grandTotal => _itemsTotal + _estimatedDeliveryFee;

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.decimalPattern('en_US');

    return Scaffold(
      backgroundColor: const Color(AppColors.backgroundValue),
      appBar: AppBar(title: const Text('ກະຕ່າ')), // Cart
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: _groups.map((group) => _buildStoreCard(group, priceFormat)).toList(),
                  ),
                ),
      bottomNavigationBar: _groups.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_groups.length > 0) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text(
                            'ຄ່າຈັດສົ່ງ (${_groups.length} ຮ້ານ): ${priceFormat.format(_estimatedDeliveryFee)} ກີບ', // Delivery fee (N stores)
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ລວມ: ${priceFormat.format(_grandTotal)} ກີບ', // Total
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(AppColors.primaryValue),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BuyerPaymentScreen(amount: _grandTotal),
                            ),
                          ).then((_) => _load()); // refresh cart (should be empty after checkout)
                        },
                        child: const Text('ຊຳລະເງິນ'), // Checkout
                      ),
                    ],
                  ),
                ],
              ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('ກະຕ່າຂອງທ່ານຫວ່າງເປົ່າ', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)), // Your cart is empty
        ],
      ),
    );
  }

  Widget _buildStoreCard(CartGroup group, NumberFormat priceFormat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(AppColors.borderValue)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.storefront, size: 16, color: Color(AppColors.primaryValue)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              children: group.items.map((item) => _buildItemRow(item, priceFormat)).toList(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'ລວມຍ່ອຍ: ${priceFormat.format(group.subtotal)} ກີບ', // Subtotal
                style: const TextStyle(color: Color(AppColors.warningValue), fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(CartItem item, NumberFormat priceFormat) {
    final qtyLabel = item.qty == item.qty.roundToDouble() ? item.qty.toInt().toString() : item.qty.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(AppColors.borderValue)),
              color: const Color(AppColors.backgroundValue),
            ),
            clipBehavior: Clip.antiAlias,
            child: item.imageUrl != null
                ? Image.network(
                    '${ApiConfig.mediaBaseUrl}${item.imageUrl}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20, color: Colors.black26),
                  )
                : const Icon(Icons.image, size: 20, color: Colors.black26),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Color(AppColors.textDarkValue)),
                ),
                if (item.variantLabel != null && item.variantLabel!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.variantLabel!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
                const SizedBox(height: 2),
                Text('ຈຳນວນ x$qtyLabel', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)), // Qty
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${priceFormat.format(item.subtotal)} ກີບ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
