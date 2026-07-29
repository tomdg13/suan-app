import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/constants.dart';
import '../../../models/banner_item.dart';
import '../../../services/banner_service.dart';
import '../../../services/api_client.dart';
import '../../../widgets/image_crop_screen.dart';
import '../../../utils/image_compress.dart';

class AdminBannersView extends StatefulWidget {
  const AdminBannersView({super.key});

  @override
  State<AdminBannersView> createState() => _AdminBannersViewState();
}

class _AdminBannersViewState extends State<AdminBannersView> {
  final _bannerService = BannerService();
  List<BannerItem> _banners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final banners = await _bannerService.getAllBanners();
    setState(() {
      _banners = banners;
      _loading = false;
    });
  }

  Future<void> _toggleActive(BannerItem banner) async {
    await _bannerService.updateBanner(banner.id, isActive: !banner.isActive);
    _load();
  }

  Future<void> _delete(BannerItem banner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete banner?'),
        content: const Text('This removes it from the storefront permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await _bannerService.deleteBanner(banner.id);
      _load();
    }
  }

  void _openForm({BannerItem? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _BannerFormSheet(existing: existing, onSaved: _load),
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
          Row(
            children: [
              const Text('Banners', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add Banner'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'These show as the swipeable promo carousel on the storefront home screen.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_banners.isEmpty) const Text('No banners yet — add one to replace the default placeholder.'),
          ..._banners.map((banner) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _fullUrl(banner.imageUrl),
                        width: 90, height: 60, fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(banner.title ?? '(no title)',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (banner.subtitle != null)
                            Text(banner.subtitle!,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _openForm(existing: banner),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _delete(banner),
                    ),
                    Switch(
                      value: banner.isActive,
                      onChanged: (_) => _toggleActive(banner),
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

class _BannerFormSheet extends StatefulWidget {
  final BannerItem? existing;
  final VoidCallback onSaved;
  const _BannerFormSheet({this.existing, required this.onSaved});

  @override
  State<_BannerFormSheet> createState() => _BannerFormSheetState();
}

class _BannerFormSheetState extends State<_BannerFormSheet> {
  final _bannerService = BannerService();
  final _imagePicker = ImagePicker();

  late final _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
  late final _subtitleCtrl = TextEditingController(text: widget.existing?.subtitle ?? '');

  Uint8List? _pickedImage;
  bool _submitting = false;
  String? _error;

  bool get _isEditMode => widget.existing != null;

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
          aspectRatio: 2.2, // wide banner shape
          title: 'Crop Banner',
        ),
      ),
    );
    if (cropped == null) return;

    setState(() {
      _pickedImage = compressImage(cropped, maxDimension: 1600, quality: 85);
    });
  }

  Future<void> _submit() async {
    if (!_isEditMode && _pickedImage == null) {
      setState(() => _error = 'A banner image is required');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isEditMode) {
        await _bannerService.updateBanner(
          widget.existing!.id,
          title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
          subtitle: _subtitleCtrl.text.trim().isEmpty ? null : _subtitleCtrl.text.trim(),
          imageBytes: _pickedImage,
        );
      } else {
        await _bannerService.createBanner(
          imageBytes: _pickedImage!,
          title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
          subtitle: _subtitleCtrl.text.trim().isEmpty ? null : _subtitleCtrl.text.trim(),
        );
      }
      widget.onSaved();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
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
          children: [
            Text(_isEditMode ? 'Edit Banner' : 'Add Banner',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: _pickedImage != null
                    ? Image.memory(_pickedImage!, fit: BoxFit.cover)
                    : (widget.existing != null
                        ? Image.network(_fullUrl(widget.existing!.imageUrl), fit: BoxFit.cover)
                        : const Center(
                            child: Icon(Icons.add_photo_alternate, size: 36, color: Colors.green))),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(_pickedImage != null || widget.existing != null ? 'Change image' : 'Pick image'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subtitleCtrl,
              decoration: const InputDecoration(labelText: 'Subtitle (optional)', border: OutlineInputBorder()),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditMode ? 'Save changes' : 'Add banner'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
