// lib/screens/admin/views/admin_logistics_providers_view.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/constants.dart';
import '../../../services/logistics_provider_service.dart';
import '../../../services/api_client.dart';
import '../../../widgets/image_crop_screen.dart';
import '../../../utils/image_compress.dart';

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

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _providers.removeAt(oldIndex);
      _providers.insert(newIndex, item);
    });
    try {
      await _service.reorderProviders(_providers.map((p) => p.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ບໍ່ສາມາດບັນທຶກລຳດັບໄດ້: \$e')),
      );
      _load();
    }
  }

  Widget _buildProviderCard(LogisticsProvider p, {required int index, required Key key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.drag_handle, color: Colors.grey),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: (p.logoUrl != null && p.logoUrl!.isNotEmpty)
                  ? Image.network(
                      '${ApiConfig.mediaBaseUrl}${p.logoUrl}',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _typeIcon(p.type),
                    )
                  : _typeIcon(p.type),
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
                  if (p.allowWeightTiers)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ຕັ້ງຄ່າສົ່ງຕາມນ້ຳໜັກໄດ້',
                          style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
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

  Widget _typeIcon(String type) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(AppColors.primaryValue).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        type == 'store_pickup'
            ? Icons.store
            : type == 'customer_courier'
                ? Icons.local_shipping_outlined
                : Icons.local_shipping,
        color: Colors.green,
        size: 22,
      ),
    );
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
            'ຕົວເລືອກທີ່ຜູ້ຊື້ຈະເຫັນຕອນຊຳລະເງິນ. ປິດການໃຊ້ງານເພື່ອເຊື່ອງໂດຍບໍ່ຕ້ອງລົບ. ລາກ ⠿ ເພື່ອຈັດລຳດັບ.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_providers.isEmpty)
            const Text('ຍັງບໍ່ມີວິທີການຈັດສົ່ງ — ກົດ "ເພີ່ມວິທີການ" ເພື່ອສ້າງ.')
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: _onReorder,
              children: [
                for (var i = 0; i < _providers.length; i++)
                  _buildProviderCard(_providers[i], index: i, key: ValueKey(_providers[i].id)),
              ],
            ),
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
  final _imagePicker = ImagePicker();

  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
  late final _sortCtrl = TextEditingController(text: (widget.existing?.sortOrder ?? 0).toString());
  late String _type = widget.existing?.type ?? 'logistic';
  late bool _isActive = widget.existing?.isActive ?? true;
  late bool _allowWeightTiers = widget.existing?.allowWeightTiers ?? false;

  Uint8List? _pickedImage;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;
  String _fullUrl(String path) => '${ApiConfig.mediaBaseUrl}$path';

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (!mounted) return;

    final rawBytes = await picked.readAsBytes();
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ImageCropScreen(
          imageBytes: rawBytes,
          aspectRatio: 1, // square logo
          title: 'ຕັດຮູບໂລໂກ້',
        ),
      ),
    );
    if (cropped == null) return;

    setState(() {
      _pickedImage = compressImage(cropped, maxDimension: 400, quality: 85);
    });
  }

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
      final description = _descCtrl.text.trim();
      final sortOrder = int.tryParse(_sortCtrl.text.trim()) ?? 0;

      if (_isEdit) {
        await _service.update(
          widget.existing!.id,
          name: name,
          description: description.isEmpty ? null : description,
          type: _type,
          isActive: _isActive,
          sortOrder: sortOrder,
          allowWeightTiers: _allowWeightTiers,
          imageBytes: _pickedImage,
        );
      } else {
        await _service.create(
          name: name,
          description: description.isEmpty ? null : description,
          type: _type,
          isActive: _isActive,
          sortOrder: sortOrder,
          allowWeightTiers: _allowWeightTiers,
          imageBytes: _pickedImage,
        );
      }
      widget.onSaved();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
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
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(AppColors.primaryValue).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(AppColors.primaryValue).withValues(alpha: 0.3)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _pickedImage != null
                      ? Image.memory(_pickedImage!, fit: BoxFit.cover)
                      : (widget.existing?.logoUrl != null && widget.existing!.logoUrl!.isNotEmpty)
                          ? Image.network(_fullUrl(widget.existing!.logoUrl!), fit: BoxFit.cover)
                          : const Icon(Icons.add_photo_alternate, size: 30, color: Colors.green),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined, size: 16),
                label: Text(
                  _pickedImage != null || (widget.existing?.logoUrl?.isNotEmpty ?? false) ? 'ປ່ຽນໂລໂກ້' : 'ເລືອກໂລໂກ້',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ອະນຸຍາດຕັ້ງຄ່າສົ່ງຕາມນ້ຳໜັກ/ຂະໜາດ'),
              subtitle: const Text(
                'ຜູ້ຂາຍຈະສາມາດຕັ້ງລະດັບຄ່າສົ່ງເອງໄດ້ສຳລັບຜູ້ໃຫ້ບໍລິການນີ້',
                style: TextStyle(fontSize: 11),
              ),
              value: _allowWeightTiers,
              activeColor: const Color(AppColors.primaryValue),
              onChanged: (v) => setState(() => _allowWeightTiers = v),
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
