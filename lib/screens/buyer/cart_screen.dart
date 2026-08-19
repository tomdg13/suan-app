import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../models/cart_item.dart';
import '../../services/cart_service.dart';
import '../../services/fee_config_service.dart';
import 'buyer_payment_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cartService = CartService();
  final _feeConfigService = FeeConfigService();
  List<CartGroup> _groups = [];
  List<FeeConfig> _activeFees = [];
  bool _loading = true;
  bool _checkingOut = false;
  bool _removingSelected = false;

  // Selected cart-item ids (by CartItem.id, not productId). Defaults to
  // "everything selected" whenever the cart reloads, matching the usual
  // Shopee/Lazada behavior.
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final groups = await _cartService.getCart();
    List<FeeConfig> activeFees = [];
    try {
      activeFees = await _feeConfigService.fetchActive();
    } catch (_) {
      // Fee lookup failing shouldn't block viewing the cart.
    }
    setState(() {
      _groups = groups;
      _activeFees = activeFees;
      _selectedIds
        ..clear()
        ..addAll(groups.expand((g) => g.items).map((i) => i.id));
      _loading = false;
    });
  }

  bool _isGroupFullySelected(CartGroup group) =>
      group.items.isNotEmpty && group.items.every((i) => _selectedIds.contains(i.id));

  bool _isGroupPartiallySelected(CartGroup group) =>
      group.items.any((i) => _selectedIds.contains(i.id)) && !_isGroupFullySelected(group);

  void _toggleItem(int itemId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(itemId);
      } else {
        _selectedIds.remove(itemId);
      }
    });
  }

  void _toggleGroup(CartGroup group, bool selected) {
    setState(() {
      for (final item in group.items) {
        if (selected) {
          _selectedIds.add(item.id);
        } else {
          _selectedIds.remove(item.id);
        }
      }
    });
  }

  // Only stores/items that have at least one selected item count toward
  // the total and the delivery fee.
  double get _itemsTotal {
    double total = 0;
    for (final group in _groups) {
      for (final item in group.items) {
        if (_selectedIds.contains(item.id)) total += item.subtotal;
      }
    }
    return total;
  }

  int get _selectedStoreCount =>
      _groups.where((g) => g.items.any((i) => _selectedIds.contains(i.id))).length;

  // Fees (delivery, insurance %, etc.) are admin-configured in /fees and
  // applied PER STORE against that store's own subtotal.
  double _selectedSubtotalForGroup(CartGroup group) {
    double total = 0;
    for (final item in group.items) {
      if (_selectedIds.contains(item.id)) total += item.subtotal;
    }
    return total;
  }

  double get _estimatedFeesTotal {
    double total = 0;
    for (final group in _groups) {
      final subtotal = _selectedSubtotalForGroup(group);
      if (subtotal <= 0) continue;
      final lines = _feeConfigService.computeFeeLines(_activeFees, subtotal);
      total += _feeConfigService.sumFeeLines(lines);
    }
    return total;
  }

  double get _grandTotal => _itemsTotal + _estimatedFeesTotal;

  bool get _hasSelection => _selectedIds.isNotEmpty;

  Future<void> _removeSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ລຶບອອກ?'), // Remove?
        content: Text('ລຶບ ${_selectedIds.length} ລາຍການທີ່ເລືອກອອກຈາກກະຕ່າ?'), // Remove N selected items from cart?
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('ຍົກເລີກ')), // Cancel
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(AppColors.errorValue)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ລຶບ'), // Remove
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _removingSelected = true);
    try {
      for (final id in _selectedIds.toList()) {
        await _cartService.removeItem(id);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ: $e')), // Error occurred
      );
    } finally {
      if (mounted) setState(() => _removingSelected = false);
    }
  }

  Future<void> _proceedToCheckout() async {
    if (!_hasSelection) return;

    // Any item the buyer UNCHECKED needs to be removed from the cart
    // first — the backend's checkout endpoint always charges the WHOLE
    // cart, grouped by store, with no partial-selection support. This
    // keeps the two in sync without needing a backend change.
    final unselected = _groups
        .expand((g) => g.items)
        .where((i) => !_selectedIds.contains(i.id))
        .toList();

    if (unselected.isEmpty) {
      _goToPayment();
      return;
    }

    setState(() => _checkingOut = true);
    try {
      for (final item in unselected) {
        await _cartService.removeItem(item.id);
      }
      if (!mounted) return;
      _goToPayment();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ: $e')), // Error occurred
      );
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  void _goToPayment() {
    // Items for the SELECTED cart items only, with unit price/qty so the
    // payment screen can show "name  price x qty = subtotal" per line.
    final items = _groups
        .expand((g) => g.items)
        .where((i) => _selectedIds.contains(i.id))
        .map((i) {
          final variantSuffix = (i.variantLabel != null && i.variantLabel!.isNotEmpty) ? ' (${i.variantLabel})' : '';
          return (name: '${i.productName}$variantSuffix', imageUrl: i.imageUrl, price: i.unitPrice, qty: i.qty, weight: i.weight);
        })
        .toList();

    // Fee breakdown across ALL selected stores, combined by fee name
    // (e.g. two stores each charging "Delivery Fee" show as one summed
    // line rather than two separate ones).
    final Map<String, double> combinedFees = {};
    for (final group in _groups) {
      final subtotal = _selectedSubtotalForGroup(group);
      if (subtotal <= 0) continue;
      final lines = _feeConfigService.computeFeeLines(_activeFees, subtotal);
      for (final line in lines) {
        combinedFees[line.name] = (combinedFees[line.name] ?? 0) + line.amount;
      }
    }
    final feeLines = combinedFees.entries.map((e) => (name: e.key, amount: e.value)).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BuyerPaymentScreen(amount: _grandTotal, items: items, feeLines: feeLines),
      ),
    ).then((_) => _load()); // refresh cart after returning
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.decimalPattern('en_US');

    return Scaffold(
      backgroundColor: const Color(AppColors.backgroundValue),
      appBar: AppBar(
        title: const Text('ກະຕ່າ'), // Cart
        actions: [
          if (_hasSelection)
            IconButton(
              icon: _removingSelected
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.delete_outline),
              tooltip: 'ລຶບລາຍການທີ່ເລືອກ', // Remove selected items
              onPressed: _removingSelected ? null : _removeSelected,
            ),
        ],
      ),
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
                    if (_selectedStoreCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Text(
                              '${_activeFees.map((f) => f.name).join(', ')} ($_selectedStoreCount ຮ້ານ): ${priceFormat.format(_estimatedFeesTotal)} ກີບ',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ລວມ (${_selectedIds.length}): ${priceFormat.format(_grandTotal)} ກີບ', // Total (N items)
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
                          onPressed: (!_hasSelection || _checkingOut) ? null : _proceedToCheckout,
                          child: Text(_checkingOut ? '...' : 'ຊຳລະເງິນ'), // Checkout
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
    final fullySelected = _isGroupFullySelected(group);
    final partiallySelected = _isGroupPartiallySelected(group);
    final selectedSubtotal = group.items
        .where((i) => _selectedIds.contains(i.id))
        .fold<double>(0, (sum, i) => sum + i.subtotal);

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
            padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
            child: Row(
              children: [
                Checkbox(
                  value: fullySelected,
                  tristate: partiallySelected,
                  activeColor: const Color(AppColors.primaryValue),
                  onChanged: (v) => _toggleGroup(group, v ?? !fullySelected),
                ),
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
                'ລວມຍ່ອຍ: ${priceFormat.format(selectedSubtotal)} ກີບ', // Subtotal (selected only)
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
    final selected = _selectedIds.contains(item.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            activeColor: const Color(AppColors.primaryValue),
            onChanged: (v) => _toggleItem(item.id, v ?? !selected),
          ),
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
