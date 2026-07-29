import 'package:flutter/material.dart';
import '../../../services/user_service.dart';
import '../../../services/api_client.dart';

/// Roles are a fixed enum on the backend (buyer/seller/admin) — there's
/// no separate "roles" table to manage. This view just gives a quick
/// breakdown of how many accounts hold each role, and explains where
/// to actually change a person's role (the Users screen).
class AdminRolesView extends StatefulWidget {
  const AdminRolesView({super.key});

  @override
  State<AdminRolesView> createState() => _AdminRolesViewState();
}

class _AdminRolesViewState extends State<AdminRolesView> {
  final _userService = UserService();
  Map<String, int> _counts = {};
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
      final users = await _userService.getAllUsers();
      final counts = <String, int>{'buyer': 0, 'seller': 0, 'admin': 0};
      for (final u in users) {
        counts[u.role] = (counts[u.role] ?? 0) + 1;
      }
      setState(() => _counts = counts);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));

    final roleInfo = [
      ('buyer', 'Buyer', Icons.shopping_bag, Colors.green),
      ('seller', 'Seller', Icons.storefront, Colors.orange),
      ('admin', 'Admin', Icons.admin_panel_settings, Colors.blueGrey),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Roles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Roles are fixed account types. To change a person\'s role, use the Users screen.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        ...roleInfo.map((r) {
          return Card(
            child: ListTile(
              leading: Icon(r.$3, color: r.$4),
              title: Text(r.$2),
              trailing: Text(
                '${_counts[r.$1] ?? 0} accounts',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
      ],
    );
  }
}
