import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/constants.dart';
import '../../../models/store.dart';
import '../../../models/product.dart';
import '../../../services/product_service.dart';
import 'product_stock_history_screen.dart';

/// Full-page stock overview for a store — every product's image, name,
/// and remaining stock, plus low/out-of-stock counts and a grand total.
/// Pushed from SellerProductsView instead of shown inline, so it has
/// room to breathe (and can grow with more columns/filters later
/// without cramping the main product management list).
class SellerStockSummaryScreen extends StatefulWidget {
  final Store store;

  const SellerStockSummaryScreen({super.key, required this.store});

  @override
  State<SellerStockSummaryScreen> createState() => _SellerStockSummaryScreenState();
}

class _SellerStockSummaryScreenState extends State<SellerStockSummaryScreen> {
  final _productService = ProductService();
  List<Product> _products = [];
  bool _loading = true;
  final Set<int> _adjusting = {};
  final Set<int> _deleting = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final products = await _productService.getProducts(
      storeId: widget.store.id,
      includeHidden: true,
    );
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  String? _fullImageUrl(String? path) {
    if (path == null) return null;
    return '${ApiConfig.mediaBaseUrl}$path';
  }

  Future<void> _adjustStock(Product p, double delta) async {
    final newStock = (p.stockQty + delta).clamp(0, double.infinity).toDouble();
    setState(() => _adjusting.add(p.id));
    try {
      await _productService.updateProduct(p.id, stockQty: newStock);
      await _load();
    } finally {
      if (mounted) setState(() => _adjusting.remove(p.id));
    }
  }

  // Tapping the quantity number opens this — for setting an exact
  // amount (ໃສ່ຈຳນວນ) instead of tapping +1/-1 repeatedly, e.g. when
  // receiving a delivery of 50 units at once.
  Future<void> _showQuantityDialog(Product p) async {
    final ctrl = TextEditingController(text: p.stockQty.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p.nameLao),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'ຈຳນວນຄົງເຫຼືອ', border: OutlineInputBorder()), // Remaining quantity
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ຍົກເລີກ')), // Cancel
          FilledButton(
            onPressed: () => Navigator.of(context).pop(double.tryParse(ctrl.text.trim())),
            child: const Text('ບັນທຶກ'), // Save
          ),
        ],
      ),
    );
    if (result == null || result < 0) return;

    setState(() => _adjusting.add(p.id));
    try {
      await _productService.updateProduct(p.id, stockQty: result);
      await _load();
    } finally {
      if (mounted) setState(() => _adjusting.remove(p.id));
    }
  }

  Future<void> _deleteProduct(Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ລຶບສິນຄ້າ?'), // Delete product?
        content: Text('ລຶບ "${p.nameLao}" ຖາວອນ? ການກະທຳນີ້ບໍ່ສາມາດຍົກເລີກໄດ້.'), // Permanently delete this product? Cannot be undone.
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('ຍົກເລີກ')), // Cancel
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(AppColors.errorValue)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ລຶບ'), // Delete
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting.add(p.id));
    try {
      await _productService.deleteProduct(p.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      // Backend blocks deletion if the product has past orders — show
      // that message (suggesting hide instead) rather than a generic error.
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('ລຶບບໍ່ໄດ້'), // Cannot delete
          content: Text('$e'.replaceFirst('Exception: ', '')),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalStock = _products.fold<double>(0, (sum, p) => sum + p.stockQty);
    final lowStockCount = _products.where((p) => p.stockQty > 0 && p.stockQty <= 5).length;
    final outOfStockCount = _products.where((p) => p.stockQty <= 0).length;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${widget.store.storeName} — Stock Summary',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a product to see its full stock movement history.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),

                  // ---- Totals row ----
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('ລວມສິນຄ້າ', '${_products.length}', const Color(AppColors.primaryValue))), // Total products
                      const SizedBox(width: 10),
                      Expanded(child: _buildStatCard('ຄົງເຫຼືອທັງໝົດ', totalStock.toStringAsFixed(0), const Color(AppColors.primaryValue))), // Total remaining
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('ໃກ້ໝົດ', '$lowStockCount', const Color(AppColors.warningValue))), // Low stock
                      const SizedBox(width: 10),
                      Expanded(child: _buildStatCard('ໝົດແລ້ວ', '$outOfStockCount', const Color(AppColors.errorValue))), // Out of stock
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ---- Per-product rows with image ----
                  if (_products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('No products yet.')),
                    )
                  else
                    ..._products.map(_buildProductRow),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(AppColors.borderValue)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildProductRow(Product p) {
    final thumbUrl = p.imageUrls.isNotEmpty ? _fullImageUrl(p.imageUrls.first) : null;
    final isOut = p.stockQty <= 0;
    final isLow = p.stockQty > 0 && p.stockQty <= 5;
    final stockColor = isOut
        ? const Color(AppColors.errorValue)
        : (isLow ? const Color(AppColors.warningValue) : const Color(AppColors.textDarkValue));
    final busy = _adjusting.contains(p.id) || _deleting.contains(p.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(AppColors.borderValue)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Info row: tapping name/image opens the full history ----
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProductStockHistoryScreen(product: p)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(AppColors.backgroundValue),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: thumbUrl != null
                      ? Image.network(
                          thumbUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20, color: Colors.black26),
                        )
                      : const Icon(Icons.image, size: 20, color: Colors.black26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nameLao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      if (!p.isActive) ...[
                        const SizedBox(height: 2),
                        Text('Hidden', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
              ],
            ),
          ),
          const Divider(height: 16),

          // ---- Action row: -1 / editable qty / +1 / delete ----
          Row(
            children: [
              _adjustButton(Icons.remove, busy || p.stockQty <= 0 ? null : () => _adjustStock(p, -1)),
              Expanded(
                child: InkWell(
                  onTap: busy ? null : () => _showQuantityDialog(p),
                  child: Center(
                    child: busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Column(
                            children: [
                              Text(
                                p.stockQty.toStringAsFixed(0),
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: stockColor),
                              ),
                              Text(
                                isOut ? 'ໝົດ' : (isLow ? 'ໃກ້ໝົດ' : 'ຄົງເຫຼືອ'), // out / low / remaining
                                style: TextStyle(fontSize: 10, color: stockColor),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              _adjustButton(Icons.add, busy ? null : () => _adjustStock(p, 1)),
              const SizedBox(width: 8),
              IconButton(
                icon: _deleting.contains(p.id)
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.delete_outline, size: 20, color: Colors.grey.shade600),
                tooltip: 'ລຶບສິນຄ້າ', // Delete product
                onPressed: busy ? null : () => _deleteProduct(p),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _adjustButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(AppColors.borderValue)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 16, color: onTap == null ? Colors.grey.shade400 : Colors.black87),
      ),
    );
  }
}
