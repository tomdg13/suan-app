import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';

/// Which status bucket this screen opens to. Matches the 5-icon row on
/// the buyer profile page (To Pay / To Ship / To Receive / To Review /
/// Returns & Cancellations). `null` (or [OrderStatusFilter.all]) shows
/// everything, same as before.
enum OrderStatusFilter { all, toPay, toShip, toReceive, toReview, returns }

class MyOrdersScreen extends StatefulWidget {
  final OrderStatusFilter initialFilter;

  const MyOrdersScreen({super.key, this.initialFilter = OrderStatusFilter.all});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final _orderService = OrderService();
  List<OrderModel> _orders = [];
  bool _loading = true;
  late OrderStatusFilter _filter;

  static const _tabs = [
    (OrderStatusFilter.all, 'All'),
    (OrderStatusFilter.toPay, 'To Pay'),
    (OrderStatusFilter.toShip, 'To Ship'),
    (OrderStatusFilter.toReceive, 'To Receive'),
    (OrderStatusFilter.toReview, 'To Review'),
    (OrderStatusFilter.returns, 'Returns'),
  ];

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await _orderService.getMyOrders();
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  // Bucket logic:
  //  - To Pay: paymentStatus unpaid AND not cancelled (buyer still owes money)
  //  - To Ship: paid/pending payment aside, status is pending or confirmed
  //    or preparing (seller hasn't shipped yet)
  //  - To Receive: status shipped (on the way)
  //  - To Review: status delivered (done, could leave a review)
  //  - Returns: status cancelled
  bool _matchesFilter(OrderModel order) {
    switch (_filter) {
      case OrderStatusFilter.all:
        return true;
      case OrderStatusFilter.toPay:
        return order.paymentStatus == 'unpaid' && order.status != 'cancelled';
      case OrderStatusFilter.toShip:
        return ['pending', 'confirmed', 'preparing'].contains(order.status);
      case OrderStatusFilter.toReceive:
        return order.status == 'shipped';
      case OrderStatusFilter.toReview:
        return order.status == 'delivered';
      case OrderStatusFilter.returns:
        return order.status == 'cancelled';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'shipped':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.decimalPattern('en_US');
    final filtered = _orders.where(_matchesFilter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: _tabs.map((tab) {
                final selected = _filter == tab.$1;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(tab.$2),
                    selected: selected,
                    selectedColor: const Color(AppColors.primaryValue),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _filter = tab.$1),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('No orders here'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final order = filtered[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            order.orderCode,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ),
                                        Text(
                                          order.status,
                                          style: TextStyle(
                                            color: _statusColor(order.status),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (order.storeName != null) ...[
                                      const SizedBox(height: 2),
                                      Text(order.storeName!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                    const SizedBox(height: 10),

                                    // Product thumbnails for everything in this order.
                                    if (order.items.isNotEmpty)
                                      SizedBox(
                                        height: 56,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: order.items.length,
                                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                                          itemBuilder: (context, i) {
                                            final item = order.items[i];
                                            return Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(AppColors.borderValue)),
                                                color: Colors.grey.shade50,
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: item.imageUrl != null
                                                  ? Image.network(
                                                      '${ApiConfig.mediaBaseUrl}${item.imageUrl}',
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.black26),
                                                    )
                                                  : const Icon(Icons.image, color: Colors.black26),
                                            );
                                          },
                                        ),
                                      ),

                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '${priceFormat.format(order.totalAmount)} ກີບ',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
