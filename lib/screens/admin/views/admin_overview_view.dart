import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/dashboard_service.dart';

class AdminOverviewView extends StatefulWidget {
  const AdminOverviewView({super.key});

  @override
  State<AdminOverviewView> createState() => _AdminOverviewViewState();
}

class _AdminOverviewViewState extends State<AdminOverviewView> {
  final _dashboardService = DashboardService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _dashboardService.getOverview();
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.decimalPattern('en_US');

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSummaryCards(priceFormat),
          const SizedBox(height: 24),
          _buildSectionTitle('Recent Orders'),
          _buildOrdersList(priceFormat),
          const SizedBox(height: 24),
          _buildSectionTitle('Top Stores'),
          _buildTopStores(priceFormat),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSummaryCards(NumberFormat priceFormat) {
    final summary = _data?['summary'] as Map<String, dynamic>? ?? {};
    final cards = [
      ('Total Sales', '${priceFormat.format(num.tryParse('${summary['total_sales']}') ?? 0)} ກີບ', Icons.payments),
      ('Total Orders', '${summary['total_orders'] ?? 0}', Icons.receipt_long),
      ('Total Stores', '${summary['total_stores'] ?? 0}', Icons.storefront),
      ('Total Customers', '${summary['total_customers'] ?? 0}', Icons.people),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: cards.map((c) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(c.$3, color: Colors.green),
                  const SizedBox(height: 8),
                  Text(c.$1, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(c.$2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildOrdersList(NumberFormat priceFormat) {
    final orders = _data?['recentOrders'] as List<dynamic>? ?? [];
    if (orders.isEmpty) return const Text('No orders yet');
    return Column(
      children: orders.take(5).map((o) {
        return Card(
          child: ListTile(
            title: Text('${o['order_code']}'),
            subtitle: Text('${o['customer']} • ${o['store_name']}'),
            trailing: Text('${priceFormat.format(num.tryParse('${o['total_amount']}') ?? 0)} ກີບ'),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopStores(NumberFormat priceFormat) {
    final stores = _data?['topStores'] as List<dynamic>? ?? [];
    if (stores.isEmpty) return const Text('No data yet');
    return Column(
      children: stores.take(5).map((s) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.storefront, color: Colors.green),
            title: Text('${s['store_name']}'),
            subtitle: Text('${s['total_orders']} orders'),
            trailing: Text('${priceFormat.format(num.tryParse('${s['total_revenue']}') ?? 0)} ກີບ'),
          ),
        );
      }).toList(),
    );
  }
}
