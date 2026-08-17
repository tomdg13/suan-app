// lib/screens/admin/views/admin_categories_view.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/constants.dart';
import '../../../models/category.dart';
import '../../../services/catalog_service.dart';
import '../../../utils/image_compress.dart';

class AdminCategoriesView extends StatefulWidget {
  const AdminCategoriesView({super.key});

  @override
  State<AdminCategoriesView> createState() => _AdminCategoriesViewState();
}

class _AdminCategoriesViewState extends State<AdminCategoriesView> {
  final _service = CatalogService();
  List<ProductCategory> _categories = [];
  String? _allIconUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_service.getCategoriesAdmin(), _service.getAllIconUrl()]);
      setState(() {
        _categories = results[0] as List<ProductCategory>;
        _allIconUrl = results[1] as String?;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(ProductCategory cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ລົບໝວດໝູ່?'),
        content: Text('ລົບ "${cat.nameLao}" ອອກຖາວອນ?'),
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
      await _service.deleteCategory(cat.id);
      _load();
    }
  }

  Future<void> _toggleActive(ProductCategory cat) async {
    await _service.updateCategory(cat.id, isActive: cat.isActive ? 0 : 1);
    _load();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
    });
    try {
      await _service.reorderCategories(_categories.map((c) => c.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ບໍ່ສາມາດບັນທຶກລຳດັບໄດ້: \$e')),
      );
      _load();
    }
  }

  Widget _buildCategoryCard(ProductCategory cat, {required int index, required Key key}) {
    final hasImage = cat.iconUrl != null && cat.iconUrl!.isNotEmpty;
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
              child: hasImage
                  ? Image.network(
                      _fullUrl(cat.iconUrl!),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.nameLao,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (cat.nameEn != null && cat.nameEn!.isNotEmpty)
                    Text(
                      cat.nameEn!,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  Text(
                    'ລຳດັບ: ${cat.sortOrder}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'ແກ້ໄຂ',
              onPressed: () => _openForm(existing: cat),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              tooltip: 'ລົບ',
              onPressed: () => _delete(cat),
            ),
            Switch(
              value: cat.isActive,
              activeColor: const Color(AppColors.primaryValue),
              onChanged: (_) => _toggleActive(cat),
            ),
          ],
        ),
      ),
    );
  }

  void _openForm({ProductCategory? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _CategoryFormSheet(existing: existing, onSaved: _load),
      ),
    );
  }

  String _fullUrl(String path) => '${ApiConfig.mediaBaseUrl}$path';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              const Text(
                'ໝວດໝູ່ສິນຄ້າ',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('ເພີ່ມໝວດ'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ໝວດໝູ່ທີ່ສະແດງຢູ່ໜ້າຫຼັກ. ສາມາດເພີ່ມຮູບໄດ້. ລາກ ⠿ ເພື່ອຈັດລຳດັບ.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // ── ທັງໝົດ special row ─────────────────────────────────
          _AllIconTile(
            iconUrl: _allIconUrl,
            onSaved: _load,
          ),
          const Divider(height: 24),
          if (_categories.isEmpty)
            const Text('ຍັງບໍ່ມີໝວດໝູ່ — ກົດ "ເພີ່ມໝວດ" ເພື່ອສ້າງ.')
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: _onReorder,
              children: [
                for (var i = 0; i < _categories.length; i++)
                  _buildCategoryCard(_categories[i], index: i, key: ValueKey(_categories[i].id)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(AppColors.primaryValue).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.category, color: Colors.green, size: 28),
    );
  }
}

// ── Form sheet ────────────────────────────────────────────────────────────────

class _CategoryFormSheet extends StatefulWidget {
  final ProductCategory? existing;
  final VoidCallback onSaved;
  const _CategoryFormSheet({this.existing, required this.onSaved});

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _service = CatalogService();
  final _picker = ImagePicker();

  late final _nameLaoCtrl =
      TextEditingController(text: widget.existing?.nameLao ?? '');
  late final _nameEnCtrl =
      TextEditingController(text: widget.existing?.nameEn ?? '');
  late final _sortCtrl = TextEditingController(
      text: (widget.existing?.sortOrder ?? 0).toString());

  Uint8List? _pickedImage;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;
  String _fullUrl(String path) => '${ApiConfig.mediaBaseUrl}$path';

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _pickedImage = compressImage(bytes, maxDimension: 800, quality: 85);
    });
  }

  Future<void> _submit() async {
    final nameLao = _nameLaoCtrl.text.trim();
    if (nameLao.isEmpty) {
      setState(() => _error = 'ກະລຸນາໃສ່ຊື່ໝວດໝູ່ (ລາວ)');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final nameEn = _nameEnCtrl.text.trim();
      final sortOrder = int.tryParse(_sortCtrl.text.trim()) ?? 0;

      if (_isEdit) {
        await _service.updateCategory(
          widget.existing!.id,
          nameLao: nameLao,
          nameEn: nameEn.isEmpty ? '' : nameEn,
          sortOrder: sortOrder,
          imageBytes: _pickedImage,
        );
      } else {
        await _service.createCategory(
          nameLao: nameLao,
          nameEn: nameEn.isEmpty ? null : nameEn,
          sortOrder: sortOrder,
          imageBytes: _pickedImage,
        );
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
    final existingImage = widget.existing?.iconUrl;
    final hasExistingImage =
        existingImage != null && existingImage.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ─────────────────────────────────────────────────
            Center(
              child: Text(
                _isEdit ? 'ແກ້ໄຂໝວດໝູ່' : 'ເພີ່ມໝວດໝູ່',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),

            // ── Image picker ──────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(AppColors.primaryValue)
                        .withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(AppColors.primaryValue)
                            .withValues(alpha: 0.3)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _pickedImage != null
                      ? Image.memory(_pickedImage!, fit: BoxFit.cover)
                      : hasExistingImage
                          ? Image.network(
                              _fullUrl(existingImage),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imgPlaceholder(),
                            )
                          : _imgPlaceholder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(
                  _pickedImage != null || hasExistingImage
                      ? 'ປ່ຽນຮູບ'
                      : 'ເລືອກຮູບ',
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Fields ────────────────────────────────────────────────
            TextField(
              controller: _nameLaoCtrl,
              decoration: const InputDecoration(
                labelText: 'ຊື່ໝວດ (ລາວ) *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameEnCtrl,
              decoration: const InputDecoration(
                labelText: 'ຊື່ໝວດ (ອັງກິດ) — optional',
                hintText: 'e.g. Vegetables',
                border: OutlineInputBorder(),
              ),
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

            // ── Error ─────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),

            // ── Submit ────────────────────────────────────────────────
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
                    : Text(_isEdit ? 'ບັນທຶກການແກ້ໄຂ' : 'ເພີ່ມໝວດໝູ່'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 32, color: Colors.green),
        SizedBox(height: 4),
        Text('ເພີ່ມຮູບ',
            style: TextStyle(fontSize: 11, color: Colors.green)),
      ],
    );
  }
}

// ── ທັງໝົດ icon tile ─────────────────────────────────────────────────────────

class _AllIconTile extends StatefulWidget {
  final String? iconUrl;
  final VoidCallback onSaved;
  const _AllIconTile({this.iconUrl, required this.onSaved});

  @override
  State<_AllIconTile> createState() => _AllIconTileState();
}

class _AllIconTileState extends State<_AllIconTile> {
  final _service = CatalogService();
  final _picker = ImagePicker();
  bool _uploading = false;

  String _fullUrl(String path) => '${ApiConfig.mediaBaseUrl}$path';

  Future<void> _pickAndUpload() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final compressed = compressImage(bytes, maxDimension: 800, quality: 85);
    setState(() => _uploading = true);
    try {
      await _service.updateAllIcon(compressed);
      widget.onSaved();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.iconUrl != null && widget.iconUrl!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: const Color(AppColors.primaryValue).withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hasImage
                  ? Image.network(_fullUrl(widget.iconUrl!), width: 60, height: 60, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ທັງໝົດ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('All categories', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('ໄອຄອນໜ້າຫຼັກ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            _uploading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'ປ່ຽນຮູບ',
                    onPressed: _pickAndUpload,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: const Color(AppColors.primaryValue).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.grid_view_rounded, color: Colors.green, size: 28),
    );
  }
}
