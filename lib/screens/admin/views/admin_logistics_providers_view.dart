// lib/screens/admin/views/admin_logistics_providers_view.dart
import 'package:flutter/material.dart';
import '../../../config/constants.dart';
import '../../../services/logistics_provider_service.dart';

class AdminLogisticsProvidersView extends StatefulWidget {
  const AdminLogisticsProvidersView({super.key});

  @override
  State<AdminLogisticsProvidersView> createState() => _AdminLogisticsProvidersViewState();
}

class _AdminLogisticsProvidersViewState extends State<AdminLogisticsProvidersView> {
  final _service = LogisticsProviderService();
  List<LogisticsProvider> _providers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final providers = await _service.fetchAll();
      setState(() => _providers = providers);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(LogisticsProvider p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ລົບວິທີການຈັດສົ່ງ?'),
        content: Text('ລົບ "${p.name}" ອອກຖາວອນ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ຍົກເລີກ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ລົບ'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.delete(p.id);
      _load();
    }
  }

  Future<void> _toggleActive(LogisticsProvider p) async {
    await _service.toggleActive(p.id);
    _load();
  }

  void _openForm({LogisticsProvider? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ProviderFormSheet(existing: existing, onSaved: _load),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'store_pickup':
        return 'ຮັບເອງທີ່ຮ້ານ';
      case 'customer_courier':
        return 'ຈັດສົ່ງມາດຕະຖານ';
      case 'logistic':
      default:
        return 'ບໍລິສັດຂົນສົ່ງ';
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
          Row(
            children: [
              const Text(
                'ວິທີການຈັດສົ່ງ',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('ເພີ່ມວິທີການ'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ຕົວເລືອກທີ່ຜູ້ຊື້ຈະເຫັນຕອນຊຳລະເງິນ. ປິດການໃຊ້ງານເພື່ອເຊື່ອງໂດຍບໍ່ຕ້ອງລົບ.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_providers.isEmpty)
            const Text('ຍັງບໍ່ມີວິທີການຈັດສົ່ງ — ກົດ "ເພີ່ມວິທີການ" ເພື່ອສ້າງ.')
          else
            ..._providers.map((p) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(AppColors.primaryValue).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          p.type == 'store_pickup'
                              ? Icons.store
                              : p.type == 'customer_courier'
                                  ? Icons.local_shipping_outlined
                                  : Icons.local_shipping,
                          color: Colors.green,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            if (p.description != null && p.description!.isNotEmpty)
                              Text(
                                p.description!,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            Text(
                              '${_typeLabel(p.type)} · ລຳດັບ: ${p.sortOrder}',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'ແກ້ໄຂ',
                        onPressed: () => _openForm(existing: p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        tooltip: 'ລົບ',
                        onPressed: () => _delete(p),
                      ),
                      Switch(
                        value: p.isActive,
                        activeColor: const Color(AppColors.primaryValue),
                        onChanged: (_) => _toggleActive(p),
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

// ── Form sheet ───────────────────────────────────────────────────────────

class _ProviderFormSheet extends StatefulWidget {
  final LogisticsProvider? existing;
  final VoidCallback onSaved;
  const _ProviderFormSheet({this.existing, required this.onSaved});

  @override
  State<_ProviderFormSheet> createState() => _ProviderFormSheetState();
}

class _ProviderFormSheetState extends State<_ProviderFormSheet> {
  final _service = LogisticsProviderService();

  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
  late final _sortCtrl = TextEditingController(text: (widget.existing?.sortOrder ?? 0).toString());
  late String _type = widget.existing?.type ?? 'logistic';
  late bool _isActive = widget.existing?.isActive ?? true;

  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'ກະລຸນາໃສ່ຊື່ວິທີການຈັດສົ່ງ');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final provider = LogisticsProvider(
        id: widget.existing?.id ?? 0,
        name: name,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        type: _type,
        isActive: _isActive,
        sortOrder: int.tryParse(_sortCtrl.text.trim()) ?? 0,
      );

      if (_isEdit) {
        await _service.update(widget.existing!.id, provider);
      } else {
        await _service.create(provider);
      }
      widget.onSaved();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                _isEdit ? 'ແກ້ໄຂວິທີການຈັດສົ່ງ' : 'ເພີ່ມວິທີການຈັດສົ່ງ',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'ຊື່ *',
                hintText: 'e.g. Anousith Logistic',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'ຄຳອະທິບາຍ — optional',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'ປະເພດ',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'logistic', child: Text('ບໍລິສັດຂົນສົ່ງ')),
                DropdownMenuItem(value: 'customer_courier', child: Text('ຈັດສົ່ງມາດຕະຖານ')),
                DropdownMenuItem(value: 'store_pickup', child: Text('ຮັບເອງທີ່ຮ້ານ')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'logistic'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sortCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ລຳດັບການສະແດງ',
                hintText: '0 = ກ່ອນໝົດ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ເປີດໃຊ້ງານ'),
              value: _isActive,
              activeColor: const Color(AppColors.primaryValue),
              onChanged: (v) => setState(() => _isActive = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'ບັນທຶກການແກ້ໄຂ' : 'ເພີ່ມວິທີການ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
