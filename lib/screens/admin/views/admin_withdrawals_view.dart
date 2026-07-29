import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/dashboard_service.dart';

/// Read-only for now — approving/paying out withdrawals needs a
/// dedicated backend endpoint (withdrawal_requests table exists in the
/// schema but has no TypeORM entity/module yet). Wire that up before
/// adding action buttons here.
class AdminWithdrawalsView extends StatefulWidget {
  const AdminWithdrawalsView({super.key});

  @override
  State<AdminWithdrawalsView> createState() => _AdminWithdrawalsViewState();
}

class _AdminWithdrawalsViewState extends State<AdminWithdrawalsView> {
  final _dashboardService = DashboardService();
  List<dynamic> _withdrawals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _dashboardService.getPendingWithdrawals();
    setState(() {
      _withdrawals = data;
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
          const Text('Withdrawal Requests',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Read-only for now — approve/pay actions need a backend endpoint.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_withdrawals.isEmpty) const Text('No pending withdrawal requests'),
          ..._withdrawals.map((w) {
            return Card(
              child: ListTile(
                title: Text('${w['store_name']}'),
                subtitle: Text('${w['bank_name'] ?? '—'} • ${w['account_number'] ?? '—'}'),
                trailing: Text(
                  '${priceFormat.format(num.tryParse('${w['amount']}') ?? 0)} ກີບ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
