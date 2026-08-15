import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import 'buyer_payment_screen.dart';

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
    (OrderStatusFilter.all, 'ທັງໝົດ'),
    (OrderStatusFilter.toPay, 'ລໍຖ້າຈ່າຍເງິນ'),
    (OrderStatusFilter.toShip, 'ລໍຈັດສົ່ງ'),
    (OrderStatusFilter.toReceive, 'ລໍຮັບເຄື່ອງ'),
    (OrderStatusFilter.toReview, 'ໃຫ້ຄະແນນ'),
    (OrderStatusFilter.returns, 'ຄືນເຄື່ອງ'),
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
  //  - To Ship: status is pending/confirmed/preparing (seller hasn't shipped yet)
  //  - To Receive: status shipped (on the way)
  //  - To Review: status delivered (done, could leave a review)
  //  - Returns: status cancelled
  bool _matchesFilter(OrderModel order) {
    switch (_filter) {
      case OrderStatusFilter.all:
        return true;
      case OrderStatusFilter.toPay:
        return order.paymentStatus == 'unpaid' && !order.proofSubmitted && order.status != 'cancelled';
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

  ({Color bg, Color fg, String label}) _statusStyle(OrderModel order) {
    if (order.status == 'cancelled') {
      return (bg: const Color(0xFFFDECEC), fg: const Color(AppColors.errorValue), label: 'ຍົກເລີກ');
    }
    if (order.paymentStatus == 'refunded') {
      return (bg: const Color(0xFFFDECEC), fg: const Color(AppColors.errorValue), label: 'ຄືນເງິນແລ້ວ');
    }
    if (order.paymentStatus == 'unpaid') {
      if (order.proofSubmitted) {
        // Buyer already paid and submitted proof — just waiting on an
        // admin to confirm it. Distinct from "hasn't paid at all".
        return (bg: const Color(0xFFEAF2FE), fg: const Color(0xFF2563EB), label: 'ສົ່ງຫຼັກຖານແລ້ວ');
      }
      return (bg: const Color(0xFFFEF3E2), fg: const Color(AppColors.warningValue), label: 'ລໍຈ່າຍເງິນ');
    }
    // paymentStatus == 'paid' from here — show real fulfillment status.
    if (order.status == 'delivered') {
      return (bg: const Color(0xFFE9F7EF), fg: const Color(AppColors.primaryValue), label: 'ຈັດສົ່ງແລ້ວ');
    }
    if (order.status == 'shipped') {
      return (bg: const Color(0xFFEAF2FE), fg: const Color(0xFF2563EB), label: 'ກຳລັງຈັດສົ່ງ');
    }
    return (bg: const Color(0xFFFEF3E2), fg: const Color(AppColors.warningValue), label: 'ກຳລັງກຽມເຄື່ອງ');
  }

  /// Contextual next-step button, matching Shopee/Lazada's pattern of one
  /// primary action per order depending on where it is in its lifecycle.
  ({String label, bool primary})? _actionFor(OrderModel order) {
    if (order.status == 'cancelled' || order.paymentStatus == 'refunded') return null;
    if (order.paymentStatus == 'unpaid') {
      // Already paid + submitted proof, just awaiting confirmation — no
      // button, nothing more for the buyer to do right now.
      if (order.proofSubmitted) return null;
      return (label: 'ຈ່າຍເງິນເລີຍ', primary: true);
    }
    if (order.status == 'shipped') return (label: 'Track Order', primary: true);
    if (order.status == 'delivered') return (label: 'Rate Order', primary: false);
    return (label: 'View Details', primary: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _orders.where(_matchesFilter).toList();

    return Scaffold(
      backgroundColor: const Color(AppColors.backgroundValue),
      appBar: AppBar(title: const Text('ຄຳສັ່ງຊື້ຂອງຂ້ອຍ')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
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
                    showCheckmark: false,
                    selectedColor: const Color(AppColors.primaryValue),
                    backgroundColor: const Color(AppColors.backgroundValue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: selected ? Colors.transparent : const Color(AppColors.borderValue)),
                    ),
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
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _OrderCard(
                            order: filtered[index],
                            statusStyle: _statusStyle(filtered[index]),
                            action: _actionFor(filtered[index]),
                            onChanged: _load,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No orders here', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final ({Color bg, Color fg, String label}) statusStyle;
  final ({String label, bool primary})? action;
  final VoidCallback onChanged;

  const _OrderCard({required this.order, required this.statusStyle, required this.action, required this.onChanged});

  Future<void> _handleAction(BuildContext context) async {
    if (action == null) return;
    if (action!.label == 'ຈ່າຍເງິນເລີຍ') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BuyerPaymentScreen(
            amount: order.totalAmount,
            existingOrderId: order.id,
            items: order.items.map((i) {
              final variantSuffix = (i.variantLabel != null && i.variantLabel!.isNotEmpty) ? ' (${i.variantLabel})' : '';
              return (name: '${i.itemName}$variantSuffix', imageUrl: i.imageUrl, price: i.unitPrice, qty: i.qty);
            }).toList(),
            feeLines: order.deliveryFee > 0 ? [(name: 'ຄ່າທຳນຽມ', amount: order.deliveryFee)] : [],
          ),
        ),
      );
      onChanged(); // refresh the list — status may now show "Payment Submitted"
      return;
    }
    // TODO: wire "Track Order" and "Rate Order" to their real screens
    // once those flows exist.
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.decimalPattern('en_US');
    final dateFormat = DateFormat('dd MMM, HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(AppColors.borderValue)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Header: store + order code + status pill ----
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.storefront, size: 15, color: Color(AppColors.primaryValue)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.storeName ?? 'Store',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(AppColors.textDarkValue)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusStyle.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusStyle.label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusStyle.fg),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ---- One row per item: image, name/variant/qty, price ----
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              children: order.items.map((item) {
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
                              item.itemName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: Color(AppColors.textDarkValue)),
                            ),
                            if (item.variantLabel != null && item.variantLabel!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.variantLabel!,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              'x${item.qty == item.qty.roundToDouble() ? item.qty.toInt() : item.qty}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${priceFormat.format(item.unitPrice)} ກີບ',
                        style: const TextStyle(fontSize: 12, color: Color(AppColors.textDarkValue)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // ---- Footer: order code + date, total, contextual action ----
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${order.orderCode} · ${dateFormat.format(order.orderDate)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ),
                    Text(
                      'ລວມ: ${priceFormat.format(order.totalAmount)} ກີບ',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(AppColors.textDarkValue)),
                    ),
                  ],
                ),
                if (action != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: action!.primary
                        ? FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(AppColors.primaryValue),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => _handleAction(context),
                            child: Text(action!.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          )
                        : OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(AppColors.primaryValue),
                              side: const BorderSide(color: Color(AppColors.primaryValue)),
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => _handleAction(context),
                            child: Text(action!.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
