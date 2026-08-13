import 'package:flutter/material.dart';
import '../../../services/dashboard_service.dart';
import '../../../services/store_service.dart';
import '../../../services/api_client.dart';

class AdminApplicationsView extends StatefulWidget {
  const AdminApplicationsView({super.key});

  @override
  State<AdminApplicationsView> createState() => _AdminApplicationsViewState();
}

class _AdminApplicationsViewState extends State<AdminApplicationsView> {
  final _dashboardService = DashboardService();
  final _storeService = StoreService();
  List<dynamic> _applications = [];
  bool _loading = true;
  int? _processingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final apps = await _dashboardService.getPendingApplications();
    setState(() {
      _applications = apps;
      _loading = false;
    });
  }

  Future<void> _approve(int id) async {
    setState(() => _processingId = id);
    try {
      await _storeService.approveApplication(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ອະນຸມັດຄຳຮ້ອງແລ້ວ — ສ້າງຮ້ານຄ້າແລ້ວ')),
      );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      setState(() => _processingId = null);
    }
  }

  Future<void> _reject(int id) async {
    setState(() => _processingId = id);
    try {
      await _storeService.rejectApplication(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ປະຕິເສດຄຳຮ້ອງແລ້ວ')),
      );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      setState(() => _processingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('ຄຳຮ້ອງສະໝັກເປັນຜູ້ຂາຍ',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_applications.isEmpty) const Text('ບໍ່ມີຄຳຮ້ອງທີ່ລໍຖ້າ'),
          ..._applications.map((app) {
            final id = app['id'] as int;
            final busy = _processingId == id;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${app['store_name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('ເຈົ້າຂອງ: ${app['owner_name']}'),
                    Text('ເບີໂທ: ${app['phone']}'),
                    if (app['product_types'] != null)
                      Text('ສິນຄ້າ: ${app['product_types']}'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: busy ? null : () => _approve(id),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('ອະນຸມັດ'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => _reject(id),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('ປະຕິເສດ'),
                        ),
                        if (busy) ...[
                          const SizedBox(width: 12),
                          const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
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
