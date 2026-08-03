import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  final _statuses = const [
    'pending', 'confirmed', 'preparing', 'shipped', 'delivered', 'cancelled'
  ];

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
    await _orderService.updateStatus(order.id, status);
    _load();
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
    final statusDropdown = DropdownButton<String>(
      value: order.status,
      isDense: true,
      items: _statuses
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (v) {
        if (v != null) _updateStatus(order, v);
      },
    );

    if (!isMobile) {
      // Unchanged desktop/web layout.
      return Card(
        child: ListTile(
          title: Text(order.orderCode),
          subtitle: Text('${priceFormat.format(order.totalAmount)} ກີບ'),
          trailing: statusDropdown,
        ),
      );
    }

    // ---- Mobile: order code + price on top (full width), status
    // dropdown on its own row below instead of squeezing into a
    // trailing column. ----
    return Card(
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
            const SizedBox(height: 4),
            Text('${priceFormat.format(order.totalAmount)} ກີບ'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: statusDropdown,
            ),
          ],
        ),
      ),
    );
  }
}