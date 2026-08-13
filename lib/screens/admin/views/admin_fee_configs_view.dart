import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/fee_config_service.dart';

class AdminFeeConfigsView extends StatefulWidget {
  const AdminFeeConfigsView({super.key});

  @override
  State<AdminFeeConfigsView> createState() => _AdminFeeConfigsViewState();
}

class _AdminFeeConfigsViewState extends State<AdminFeeConfigsView> {
  final _feeService = FeeConfigService();
  List<FeeConfig> _fees = [];
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
      final fees = await _feeService.fetchAll();
      setState(() {
        _fees = fees;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'ໂຫລດບໍ່ສຳເລັດ: $e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleActive(FeeConfig fee) async {
    try {
      await _feeService.update(fee.id, isActive: !fee.isActive);
      _load();
    } on ApiException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _delete(FeeConfig fee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ລຶບຄ່າທຳນຽມ?'),
        content: Text('"${fee.name}" ຈະບໍ່ຖືກນຳໃຊ້ກັບຄໍາສັ່ງຊື້ໃໝ່ອີກ. ຄໍາສັ່ງຊື້ເກົ່າຈະຍັງຄົງປະຫວັດຄ່າທຳນຽມເດີມ.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('ຍົກເລີກ')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('ລຶບ')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _feeService.delete(fee.id);
      _load();
    } on ApiException catch (e) {
      _showError(e.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openForm({FeeConfig? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _FeeFormSheet(existing: existing, onSaved: _load),
      ),
    );
  }

  String _valueLabel(FeeConfig fee) {
    final priceStyleValue = fee.value == fee.value.roundToDouble() ? fee.value.toInt().toString() : fee.value.toString();
    return fee.type == FeeType.percent ? '$priceStyleValue%' : '$priceStyleValue LAK';
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
              const Text('ຄ່າທຳນຽມ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('ເພີ່ມຄ່າທຳນຽມ'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ຄ່າທຳນຽມຈະບວກເພີ່ມເທິງຍອດລວມຕອນຊຳລະເງິນ - ແບບຄົງທີ່ (LAK ຕາຍຕົວ) ຫຼືເປັນເປີເຊັນ '
            '(ເປີເຊັນຂອງຍອດຮ້ານນັ້ນ). ຄ່າທຳນຽມທີ່ເປີດໃຊ້ຢູ່ຈະນຳໃຊ້ກັບທຸກຄໍາສັ່ງຊື້. '
            'ການແກ້ໄຂຄ່າທຳນຽມມີຜົນສະເພາະຄໍາສັ່ງຊື້ໃໝ່ - ຄໍາສັ່ງຊື້ເກົ່າຍັງຄົງຈຳນວນທີ່ຖືກຄິດໄວ້ເດີມ.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],
          if (_fees.isEmpty && _error == null) const Text('ຍັງບໍ່ມີການຕັ້ງຄ່າຄ່າທຳນຽມ - ເພີ່ມອັນໜຶ່ງ (ເຊັ່ນ: ຄ່າຈັດສົ່ງ).'),
          ..._fees.map((fee) {
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: fee.type == FeeType.percent ? Colors.orange.shade50 : Colors.green.shade50,
                  child: Icon(
                    fee.type == FeeType.percent ? Icons.percent : Icons.attach_money,
                    color: fee.type == FeeType.percent ? Colors.orange.shade700 : Colors.green.shade700,
                    size: 20,
                  ),
                ),
                title: Text(fee.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${fee.type == FeeType.percent ? "ເປີເຊັນ" : "ຄົງທີ່"} - ${_valueLabel(fee)} - ລຳດັບ ${fee.sortOrder}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _openForm(existing: fee),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _delete(fee),
                    ),
                    Switch(
                      value: fee.isActive,
                      onChanged: (_) => _toggleActive(fee),
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

class _FeeFormSheet extends StatefulWidget {
  final FeeConfig? existing;
  final VoidCallback onSaved;
  const _FeeFormSheet({this.existing, required this.onSaved});

  @override
  State<_FeeFormSheet> createState() => _FeeFormSheetState();
}

class _FeeFormSheetState extends State<_FeeFormSheet> {
  final _feeService = FeeConfigService();

  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _valueCtrl = TextEditingController(
    text: widget.existing != null
        ? (widget.existing!.value == widget.existing!.value.roundToDouble()
            ? widget.existing!.value.toInt().toString()
            : widget.existing!.value.toString())
        : '',
  );
  late final _sortCtrl = TextEditingController(text: '${widget.existing?.sortOrder ?? 0}');

  late FeeType _type = widget.existing?.type ?? FeeType.flat;
  late bool _isActive = widget.existing?.isActive ?? true;

  bool _submitting = false;
  String? _error;

  bool get _isEditMode => widget.existing != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final value = double.tryParse(_valueCtrl.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'ຕ້ອງລະບຸຊື່');
      return;
    }
    if (value == null || value < 0) {
      setState(() => _error = 'ກະລຸນາໃສ່ຄ່າທີ່ຖືກຕ້ອງ, ບໍ່ຕິດລົບ');
      return;
    }
    final sortOrder = int.tryParse(_sortCtrl.text.trim()) ?? 0;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isEditMode) {
        await _feeService.update(
          widget.existing!.id,
          name: name,
          type: _type,
          value: value,
          sortOrder: sortOrder,
          isActive: _isActive,
        );
      } else {
        await _feeService.create(
          name: name,
          type: _type,
          value: value,
          sortOrder: sortOrder,
          isActive: _isActive,
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEditMode ? 'ແກ້ໄຂຄ່າທຳນຽມ' : 'ເພີ່ມຄ່າທຳນຽມ',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'ຊື່',
                hintText: 'ຕົວຢ່າງ ຄ່າຈັດສົ່ງ, ຄ່າປະກັນໄພ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<FeeType>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'ປະເພດ', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: FeeType.flat, child: Text('ຄົງທີ່ (LAK)')),
                      DropdownMenuItem(value: FeeType.percent, child: Text('ເປີເຊັນ (%)')),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? FeeType.flat),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _valueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _type == FeeType.percent ? 'ຄ່າ (%)' : 'ຄ່າ (LAK)',
                      hintText: _type == FeeType.percent ? 'ຕົວຢ່າງ 15' : 'ຕົວຢ່າງ 20000',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _type == FeeType.percent
                  ? 'ນຳໃຊ້ເປັນເປີເຊັນຂອງຍອດຮ້ານແຕ່ລະຮ້ານ (ບໍ່ແມ່ນຍອດລວມກະຕ່າທັງໝົດ).'
                  : 'ຈຳນວນ LAK ຄົງທີ່ ນຳໃຊ້ຄັ້ງດຽວຕໍ່ຄໍາສັ່ງຊື້ຂອງແຕ່ລະຮ້ານ.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sortCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ລຳດັບ (ບໍ່ບັງຄັບ)',
                hintText: 'ຕົວເລກນ້ອຍສະແດງກ່ອນ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ເປີດໃຊ້ງານ'),
              subtitle: const Text('ຄ່າທຳນຽມທີ່ປິດຢູ່ ຈະບໍ່ນຳໃຊ້ກັບຄໍາສັ່ງຊື້ໃໝ່'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
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
                  : Text(_isEditMode ? 'ບັນທຶກການປ່ຽນແປງ' : 'ເພີ່ມຄ່າທຳນຽມ'),
            ),
          ],
        ),
      ),
    );
  }
}
