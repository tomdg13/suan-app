import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/constants.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';

/// Admin queue: orders where the buyer has uploaded a payment screenshot
/// + RRN but nobody has confirmed the money actually landed in the
/// store's bank account yet. Confirming here marks paymentStatus: paid
/// and moves the order to CONFIRMED, so the seller can start packing.
class AdminPaymentConfirmationsView extends StatefulWidget {
  const AdminPaymentConfirmationsView({super.key});

  @override
  State<AdminPaymentConfirmationsView> createState() => _AdminPaymentConfirmationsViewState();
}

class _AdminPaymentConfirmationsViewState extends State<AdminPaymentConfirmationsView> {
  final _orderService = OrderService();
  List<OrderModel> _orders = [];
  bool _loading = true;
  final Set<int> _confirming = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await _orderService.getPendingPaymentConfirmations();
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  Future<void> _confirm(OrderModel order) async {
    setState(() => _confirming.add(order.id));
    try {
      await _orderService.confirmPayment(order.id);
      if (!mounted) return;
      setState(() {
        _orders.removeWhere((o) => o.id == order.id);
        _confirming.remove(order.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${order.orderCode} confirmed as paid')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming.remove(order.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not confirm: $e')),
      );
    }
  }

  void _showFullscreen(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.network('${ApiConfig.mediaBaseUrl}$imageUrl'),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final priceFormat = NumberFormat.decimalPattern('en_US');
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Text('Payment Confirmations', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              if (_orders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.warningValue).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_orders.length} pending',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(AppColors.warningValue)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Buyers who uploaded payment proof — verify the money actually arrived before confirming.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          if (_orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('Nothing waiting on confirmation', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),

          ..._orders.map((order) {
            final isConfirming = _confirming.contains(order.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Screenshot thumbnail — tap to view full size.
                    if (order.paymentProofUrl != null)
                      GestureDetector(
                        onTap: () => _showFullscreen(order.paymentProofUrl!),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(AppColors.borderValue)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            '${ApiConfig.mediaBaseUrl}${order.paymentProofUrl}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.receipt_long, color: Colors.black26),
                          ),
                        ),
                      ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.orderCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            '${order.buyerName ?? 'Unknown buyer'} · ${order.buyerPhone ?? ''}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          if (order.storeName != null)
                            Text(order.storeName!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text('RRN: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Expanded(
                                child: Text(
                                  order.rrn?.isNotEmpty == true ? order.rrn! : '(not provided)',
                                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(dateFormat.format(order.orderDate), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${priceFormat.format(order.totalAmount)} ກີບ',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 34,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(AppColors.primaryValue),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: isConfirming ? null : () => _confirm(order),
                            child: Text(
                              isConfirming ? '...' : 'Confirm Payment',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
