import 'package:flutter/material.dart';
import '../../../models/store.dart';
import '../../../services/store_service.dart';

class AdminStoresView extends StatefulWidget {
  const AdminStoresView({super.key});

  @override
  State<AdminStoresView> createState() => _AdminStoresViewState();
}

class _AdminStoresViewState extends State<AdminStoresView> {
  final _storeService = StoreService();
  List<Store> _stores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stores = await _storeService.getStores();
    setState(() {
      _stores = stores;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Stores', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_stores.isEmpty) const Text('No stores yet'),
          ..._stores.map((store) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.storefront, color: Colors.green),
                title: Text(store.storeName),
                subtitle: Text(store.province ?? '—'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (store.isVerified)
                      const Icon(Icons.verified, color: Colors.blue, size: 18),
                    const SizedBox(width: 6),
                    Text('★ ${store.ratingAvg}'),
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
