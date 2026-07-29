import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/constants.dart';
import '../../../models/store.dart';
import '../../../services/store_service.dart';
import '../../../services/upload_service.dart';
import '../../../services/api_client.dart';
import '../../../widgets/image_crop_screen.dart';
import '../../../utils/image_compress.dart';

class SellerStoreProfileView extends StatefulWidget {
  final Store? store;
  final ValueChanged<Store> onStoreUpdated;

  const SellerStoreProfileView({
    super.key,
    required this.store,
    required this.onStoreUpdated,
  });

  @override
  State<SellerStoreProfileView> createState() => _SellerStoreProfileViewState();
}

class _SellerStoreProfileViewState extends State<SellerStoreProfileView> {
  final _storeService = StoreService();
  final _uploadService = UploadService();
  final _imagePicker = ImagePicker();

  final _nameCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();

  String? _uploadingType; // 'logo' | 'cover' | null
  bool _saving = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _fillFromStore();
  }

  @override
  void didUpdateWidget(covariant SellerStoreProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store?.id != widget.store?.id) _fillFromStore();
  }

  void _fillFromStore() {
    final store = widget.store;
    _nameCtrl.text = store?.storeName ?? '';
    _provinceCtrl.text = store?.province ?? '';
    _descCtrl.text = ''; // description isn't in the Store model's list view — left blank to edit fresh
  }

  Future<void> _pickAndUpload(String type) async {
    final store = widget.store;
    if (store == null) return;

    // 1. Pick from gallery
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (!mounted) return;

    // 2. Let the person crop it — square for the logo, wide banner for the cover
    final rawBytes = await picked.readAsBytes();
    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ImageCropScreen(
          imageBytes: rawBytes,
          aspectRatio: type == 'logo' ? 1.0 : 3.0,
          title: type == 'logo' ? 'Crop Logo' : 'Crop Cover Photo',
        ),
      ),
    );
    if (croppedBytes == null) return; // they backed out of cropping
    if (!mounted) return;

    setState(() {
      _uploadingType = type;
      _error = null;
    });
    try {
      // 3. Resize + compress so upload stays small and consistent
      final compressed = compressImage(
        croppedBytes,
        maxDimension: type == 'logo' ? 800 : 1600,
        quality: 85,
      );

      final updated = await _uploadService.uploadStoreImageBytes(
        storeId: store.id,
        type: type,
        bytes: compressed,
        filename: '$type.jpg',
      );
      widget.onStoreUpdated(updated);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _uploadingType = null);
    }
  }

  Future<void> _save() async {
    final store = widget.store;
    if (store == null) return;

    setState(() {
      _saving = true;
      _error = null;
      _successMessage = null;
    });
    try {
      final updated = await _storeService.updateStore(
        store.id,
        storeName: _nameCtrl.text.trim(),
        province: _provinceCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        whatsapp: _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
      );
      widget.onStoreUpdated(updated);
      setState(() => _successMessage = 'Saved!');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _saving = false);
    }
  }

  String? _fullImageUrl(String? path) {
    if (path == null) return null;
    return '${ApiConfig.mediaBaseUrl}$path';
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    if (store == null) {
      return const Center(child: Text('Select or create a store first (Store Status tab).'));
    }

    final coverUrl = _fullImageUrl(store.coverUrl);
    final logoUrl = _fullImageUrl(store.logoUrl);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Store Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // ---- Cover + logo ----
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: _uploadingType != null ? null : () => _pickAndUpload('cover'),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      color: Colors.green.shade50,
                      child: coverUrl != null
                          ? Image.network(coverUrl, fit: BoxFit.cover)
                          : const Center(
                              child: Icon(Icons.add_photo_alternate, size: 40, color: Colors.green)),
                    ),
                  ),
                  if (_uploadingType == 'cover')
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black38,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FilledButton.tonalIcon(
                      onPressed: _uploadingType != null ? null : () => _pickAndUpload('cover'),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Cover'),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: -32,
                    child: GestureDetector(
                      onTap: _uploadingType != null ? null : () => _pickAndUpload('logo'),
                      child: Stack(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              color: Colors.green.shade100,
                              image: logoUrl != null
                                  ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: logoUrl == null
                                ? const Icon(Icons.storefront, color: Colors.green)
                                : null,
                          ),
                          if (_uploadingType == 'logo')
                            Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black38,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Tap the cover or logo to change it',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ---- Editable profile fields ----
        const Text('Store Details', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Store name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _provinceCtrl,
          decoration: const InputDecoration(labelText: 'Province', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Description', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _whatsappCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'WhatsApp', border: OutlineInputBorder()),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        if (_successMessage != null) ...[
          const SizedBox(height: 12),
          Text(_successMessage!, style: const TextStyle(color: Colors.green)),
        ],

        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save changes'),
        ),
      ],
    );
  }
}
