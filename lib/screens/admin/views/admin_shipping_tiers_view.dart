import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../services/shipping_tier_service.dart';

const int _kMaxTiers = 10;

class AdminShippingTiersView extends StatefulWidget {
  const AdminShippingTiersView({super.key});

  @override
  State<AdminShippingTiersView> createState() => _AdminShippingTiersViewState();
}

class _AdminShippingTiersViewState extends State<AdminShippingTiersView> {
  final _tierService = ShippingTierService();
  List<ShippingTier> _tiers = [];
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
      final tiers = await _tierService.fetchAll();
      tiers.sort((a, b) => a.minWeight.compareTo(b.minWeight));
      setState(() {
        _tiers = tiers;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'ໂຫລດບໍ່ສຳເລັດ: $e';
        _loading = false;
      });
    }
  }

  Future<void> _delete(ShippingTier tier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ລຶບຂັ້ນຄ່າຂົນສົງ?'),
        content: Text(
          'ຂັ້ນ ${_rangeLabel(tier)} → ${_priceLabel(tier.price)} ຈະຖືກລຶບ. '
          'ຄໍາສັ່ງຊື້ໃໝ່ຈະບໍ່ນຳໃຊ້ຂັ້ນນີ້ອີກ.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('ຍົກເລີກ')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('ລຶບ')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _tierService.delete(tier.id);
      _load();
    } on ApiException catch (e) {
      _showError(e.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openForm({ShippingTier? existing}) {
    if (existing == null && _tiers.length >= _kMaxTiers) {
      _showError('ອະນຸຍາດສູງສຸດ $_kMaxTiers ຂັ້ນ');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _TierFormSheet(existing: existing, allTiers: _tiers, onSaved: _load),
      ),
    );
  }

  String _priceLabel(int price) => '${NumberFormat.decimalPattern('en_US').format(price)} ກີບ';

  String _rangeLabel(ShippingTier tier) {
    final minLabel = tier.minWeight == tier.minWeight.roundToDouble()
        ? tier.minWeight.toInt().toString()
        : tier.minWeight.toString();
    if (tier.maxWeight == null) return '$minLabel ກິໂລ ຂຶ້ນໄປ';
    final maxLabel = tier.maxWeight! == tier.maxWeight!.roundToDouble()
        ? tier.maxWeight!.toInt().toString()
        : tier.maxWeight!.toString();
    return '$minLabel - $maxLabel ກິໂລ';
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
              const Text('ຄ່າຂົນສົງ (ຕາມນ້ຳໜັກ)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _tiers.length >= _kMaxTiers ? null : () => _openForm(),
                icon: const Icon(Icons.add),
                label: Text('ເພີ່ມຂັ້ນ (${_tiers.length}/$_kMaxTiers)'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ກຳນົດຄ່າຂົນສົງຕາມນ້ຳໜັກລວມຂອງກະຕ່າ (ກິໂລ) - ສູງສຸດ $_kMaxTiers ຂັ້ນ. '
            'ຂອບເຂດນ້ຳໜັກຂອງແຕ່ລະຂັ້ນຈະຄິດໄລ່ອັດຕະໂນມັດຈາກຂັ້ນທີ່ມີຢູ່ແລ້ວ.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],
          if (_tiers.isEmpty && _error == null)
            const Text('ຍັງບໍ່ມີການຕັ້ງຄ່າຂັ້ນຄ່າຂົນສົງ - ເພີ່ມອັນໜຶ່ງ.'),
          ..._tiers.map((tier) {
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.local_shipping_outlined, color: Colors.blue.shade700, size: 20),
                ),
                title: Text(_rangeLabel(tier), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_priceLabel(tier.price)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _openForm(existing: tier),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _delete(tier),
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

class _TierFormSheet extends StatefulWidget {
  final ShippingTier? existing;
  final List<ShippingTier> allTiers;
  final VoidCallback onSaved;
  const _TierFormSheet({this.existing, required this.allTiers, required this.onSaved});

  @override
  State<_TierFormSheet> createState() => _TierFormSheetState();
}

class _TierFormSheetState extends State<_TierFormSheet> {
  final _tierService = ShippingTierService();

  late final _maxWeightCtrl = TextEditingController(
    text: widget.existing?.maxWeight != null
        ? (widget.existing!.maxWeight! == widget.existing!.maxWeight!.roundToDouble()
            ? widget.existing!.maxWeight!.toInt().toString()
            : widget.existing!.maxWeight!.toString())
        : '',
  );
  late final _priceCtrl = TextEditingController(text: '${widget.existing?.price ?? ''}');

  bool _submitting = false;
  String? _error;

  bool get _isEditMode => widget.existing != null;

  // The lower bound is never typed by hand — it's always "one step past"
  // wherever the previous tier (by minWeight) currently ends.
  double get _computedMinWeight {
    if (_isEditMode) return widget.existing!.minWeight;
    final others = widget.allTiers.where((t) => t.maxWeight != null).toList()
      ..sort((a, b) => a.minWeight.compareTo(b.minWeight));
    if (others.isEmpty) return 0;
    return double.parse((others.last.maxWeight! + 0.01).toStringAsFixed(2));
  }

  String _fmtWeight(double w) => w == w.roundToDouble() ? w.toInt().toString() : w.toString();

  @override
  void dispose() {
    _maxWeightCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final maxWeight = double.tryParse(_maxWeightCtrl.text.trim());
    final price = int.tryParse(_priceCtrl.text.trim());
    final minWeight = _computedMinWeight;

    if (maxWeight == null || maxWeight <= 0) {
      setState(() => _error = 'ກະລຸນາໃສ່ນ້ຳໜັກ (ກິໂລ) ທີ່ຖືກຕ້ອງ');
      return;
    }
    if (maxWeight <= minWeight) {
      setState(() => _error = 'ນ້ຳໜັກຕ້ອງຫຼາຍກວ່າ ${_fmtWeight(minWeight)} ກິໂລ (ຂັ້ນກ່ອນໜ້າ)');
      return;
    }
    if (price == null || price < 0) {
      setState(() => _error = 'ກະລຸນາໃສ່ລາຄາທີ່ຖືກຕ້ອງ, ບໍ່ຕິດລົບ');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isEditMode) {
        await _tierService.update(
          widget.existing!.id,
          maxWeight: maxWeight,
          price: price,
        );
      } else {
        await _tierService.create(
          minWeight: minWeight,
          maxWeight: maxWeight,
          price: price,
          sortOrder: widget.allTiers.length,
        );
      }
      widget.onSaved();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final minWeight = _computedMinWeight;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEditMode ? 'ແກ້ໄຂຂັ້ນຄ່າຂົນສົງ' : 'ເພີ່ມຂັ້ນຄ່າຂົນສົງ',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'ນ້ຳໜັກເລີ່ມຕົ້ນ: ${_fmtWeight(minWeight)} ກິໂລ (ຄິດໄລ່ອັດຕະໂນມັດ)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            // Box 1 — weight cutoff (kg)
            TextField(
              controller: _maxWeightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'ນ້ຳໜັກບໍ່ເກີນ (ກິໂລ)',
                hintText: 'ຕົວຢ່າງ 5, 10, 20',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Box 2 — delivery price
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ຄ່າຂົນສົງ (ກີບ)',
                hintText: 'ຕົວຢ່າງ 20000',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditMode ? 'ບັນທຶກການປ່ຽນແປງ' : 'ເພີ່ມຂັ້ນ'),
            ),
          ],
        ),
      ),
    );
  }
}
