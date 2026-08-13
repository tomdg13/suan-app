import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/dashboard_service.dart';
/// Basic version: shows the recent-orders feed from the dashboard
/// overview endpoint. A dedicated paginated "all orders" endpointwould
/// be a good next step once order volume grows.
class AdminOrdersView extends StatefulWidget {
  const AdminOrdersView({super.key});
  @override
  State<AdminOrdersView> createState() => _AdminOrdersViewState();
}
class _AdminOrdersViewState extends State<AdminOrdersView> {
  final _dashboardService = DashboardService();
  List<dynamic> _orders = [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _dashboardService.getOverview();
    setState(() {
      _orders = data['recentOrders'] as List<dynamic>? ?? [];
      _loading = false;
    });
  }
  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.decimalPattern('en_US');
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('ຄໍາສັ່ງຊື້ທັງໝົດ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_orders.isEmpty) const Text('ຍັງບໍ່ມີຄໍາສັ່ງຊື້'),
          ..._orders.map((o) {
            return Card(
              child: ListTile(
                title: Text('${o['order_code']}'),
                subtitle: Text('${o['customer']} • ${o['store_name']} • ${o['status']}'),
                trailing: Text('${priceFormat.format(num.tryParse('${o['total_amount']}') ?? 0)} ກີບ'),
              ),
            );
          }),
        ],
      ),
    );
  }
}
