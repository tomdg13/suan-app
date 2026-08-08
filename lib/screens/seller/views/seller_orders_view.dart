import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/constants.dart';
import '../../../models/store.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';

// Same breakpoint used across the seller screens (shell, products, profile)
// for consistency.
const double _kMobileBreakpoint = 700;

class SellerOrdersView extends StatefulWidget {
  final Store? store;
  const SellerOrdersView({super.key, required this.store});

  @override
  State<SellerOrdersView> createState() => _SellerOrdersViewState();
}

class _SellerOrdersViewState extends State<SellerOrdersView> {
  final _orderService = OrderService();
  List<OrderModel> _orders = [];
  bool _loading = true;
  final Set<int> _updating = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SellerOrdersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store?.id != widget.store?.id) _load();
  }

  Future<void> _load() async {
    if (widget.store == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final orders = await _orderService.getStoreOrders(widget.store!.id);
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  Future<void> _updateStatus(OrderModel order, String status) async {
    setState(() => _updating.add(order.id));
    try {
      await _orderService.updateStatus(order.id, status);
      await _load();
    } finally {
      if (mounted) setState(() => _updating.remove(order.id));
    }
  }

  /// The single next step in the fulfillment pipeline, or null if
  /// there's nothing left to do (delivered/cancelled). Deliberately NOT
  /// a free-pick dropdown — sellers move forward one stage at a time so
  /// they can't accidentally skip straight to "delivered" or jump
  /// backward.
  ({String status, String label})? _nextStep(OrderModel order) {
    switch (order.status) {
      case 'pending':
      case 'confirmed':
        return (status: 'preparing', label: 'Start Preparing');
      case 'preparing':
        return (status: 'shipped', label: 'Mark Shipped');
      case 'shipped':
        return (status: 'delivered', label: 'Mark Delivered');
      default:
        return null; // delivered or cancelled — nothing more to do
    }
  }

  ({Color bg, Color fg, String label}) _statusStyle(String status) {
    switch (status) {
      case 'delivered':
        return (bg: const Color(0xFFE9F7EF), fg: const Color(AppColors.primaryValue), label: 'Delivered');
      case 'cancelled':
        return (bg: const Color(0xFFFDECEC), fg: const Color(AppColors.errorValue), label: 'Cancelled');
      case 'shipped':
        return (bg: const Color(0xFFEAF2FE), fg: const Color(0xFF2563EB), label: 'Shipped');
      case 'preparing':
        return (bg: const Color(0xFFFEF3E2), fg: const Color(AppColors.warningValue), label: 'Preparing');
      default:
        return (bg: const Color(0xFFFEF3E2), fg: const Color(AppColors.warningValue), label: 'Confirmed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.decimalPattern('en_US');

    if (widget.store == null) {
      return const Center(child: Text('Select or create a store first (Store Status tab).'));
    }
    if (_loading) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _kMobileBreakpoint;

        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${widget.store!.storeName} — Orders',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: isMobile ? 2 : 1,
              ),
              const SizedBox(height: 16),
              if (_orders.isEmpty) const Text('No orders yet'),
              ..._orders.map((order) => _buildOrderCard(order, priceFormat, isMobile)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(OrderModel order, NumberFormat priceFormat, bool isMobile) {
    final isPaid = order.paymentStatus == 'paid';
    final isUpdating = _updating.contains(order.id);
    final next = _nextStep(order);
    final style = _statusStyle(order.status);

    Widget statusArea;
    if (order.status == 'cancelled') {
      statusArea = _statusPill(style);
    } else if (!isPaid) {
      // Not paid yet (or proof not yet confirmed by admin) — nothing
      // for the seller to do but wait.
      statusArea = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              order.proofSubmitted ? 'Awaiting payment confirmation' : 'Awaiting payment',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
          ),
        ],
      );
    } else if (next == null) {
      // Paid and already fully delivered.
      statusArea = _statusPill(style);
    } else {
      // Paid, still moving through fulfillment — status pill + the one
      // next-step button.
      statusArea = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statusPill(style),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryValue),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: isUpdating ? null : () => _updateStatus(order, next.status),
              child: Text(
                isUpdating ? '...' : next.label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    if (!isMobile) {
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(order.orderCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  statusArea,
                ],
              ),
              const Divider(height: 20),
              ..._buildItemRows(order, priceFormat),
              const SizedBox(height: 8),
              _buildSummaryRow('Delivery Fee', order.deliveryFee, priceFormat),
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: ${priceFormat.format(order.totalAmount)} ກີບ',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ---- Mobile ----
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.orderCode,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            ..._buildItemRows(order, priceFormat),
            const SizedBox(height: 6),
            _buildSummaryRow('Delivery Fee', order.deliveryFee, priceFormat),
            const Divider(height: 20),
            Text(
              'Total: ${priceFormat.format(order.totalAmount)} ກີບ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: statusArea,
            ),
          ],
        ),
      ),
    );
  }

  /// One row per item: thumbnail, name × qty, and the line subtotal
  /// (qty × unit price). Same visual pattern as the buyer's order screen.
  List<Widget> _buildItemRows(OrderModel order, NumberFormat priceFormat) {
    return order.items.map((item) {
      final qtyLabel = item.qty == item.qty.roundToDouble() ? item.qty.toInt().toString() : item.qty.toString();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
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
                      errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 18, color: Colors.black26),
                    )
                  : const Icon(Icons.image, size: 18, color: Colors.black26),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.itemName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  if (item.variantLabel != null && item.variantLabel!.isNotEmpty)
                    Text(item.variantLabel!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Text(
                    'x$qtyLabel × ${priceFormat.format(item.unitPrice)} ກີບ',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Text(
              '${priceFormat.format(item.subtotal)} ກີບ',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSummaryRow(String label, double amount, NumberFormat priceFormat) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const Spacer(),
        Text('${priceFormat.format(amount)} ກີບ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _statusPill(({Color bg, Color fg, String label}) style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(20)),
      child: Text(style.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: style.fg)),
    );
  }
}
