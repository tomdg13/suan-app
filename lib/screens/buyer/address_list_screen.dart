import 'package:flutter/material.dart';
import '../../config/constants.dart';
import '../../models/user_address.dart';
import '../../services/address_service.dart';
import 'address_form_screen.dart';

class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  final _service = AddressService();
  List<UserAddress> _addresses = [];
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
      final list = await _service.findMine();
      // Default address always shown first.
      list.sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0));
      setState(() => _addresses = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addNew() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddressFormScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _edit(UserAddress address) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddressFormScreen(existing: address)),
    );
    if (result == true) _load();
  }

  Future<void> _setDefault(UserAddress address) async {
    if (address.isDefault) return;
    try {
      await _service.setDefault(address.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _delete(UserAddress address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ລຶບທີ່ຢູ່'),
        content: Text('ລຶບ "${address.recipientName}" ອອກຈາກລາຍການບໍ່?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ຍົກເລີກ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ລຶບ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.remove(address.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.backgroundValue),
      appBar: AppBar(
        title: const Text('ທີ່ຢູ່ຂອງຂ້ອຍ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNew,
        icon: const Icon(Icons.add),
        label: const Text('ເພີ່ມທີ່ຢູ່'),
        backgroundColor: const Color(AppColors.primaryValue),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _addresses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_off_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('ຍັງບໍ່ມີທີ່ຢູ່', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                        itemCount: _addresses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _AddressCard(
                          address: _addresses[index],
                          onEdit: () => _edit(_addresses[index]),
                          onDelete: () => _delete(_addresses[index]),
                          onSetDefault: () => _setDefault(_addresses[index]),
                        ),
                      ),
                    ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final UserAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: address.isDefault
            ? Border.all(color: const Color(AppColors.primaryValue), width: 1.4)
            : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LabelChip(label: address.label),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address.recipientName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (address.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.primaryValue).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ຄ່າເລີ່ມຕົ້ນ',
                    style: TextStyle(fontSize: 11, color: Color(AppColors.primaryValue), fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(address.phone, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(address.shortDisplay, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          if (address.hasPin) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'ມີໝຸດຕຳແໜ່ງແລ້ວ',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!address.isDefault)
                TextButton(onPressed: onSetDefault, child: const Text('ຕັ້ງເປັນຄ່າເລີ່ມຕົ້ນ')),
              TextButton(onPressed: onEdit, child: const Text('ແກ້ໄຂ')),
              TextButton(
                onPressed: onDelete,
                child: const Text('ລຶບ', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  final String label;
  const _LabelChip({required this.label});

  IconData get _icon {
    switch (label.toLowerCase()) {
      case 'work':
      case 'office':
        return Icons.work_outline;
      default:
        return Icons.home_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 13, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
