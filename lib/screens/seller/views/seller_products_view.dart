import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/constants.dart';
import '../../../models/store.dart';
import '../../../models/product.dart';
import '../../../models/category.dart';
import '../../../models/unit.dart';
import '../../../services/product_service.dart';
import '../../../services/catalog_service.dart';
import '../../../services/upload_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/image_compress.dart';

// Below this width the header stacks (title above the button instead of
// side-by-side) and product cards switch to a compact layout that doesn't
// squeeze the "Stock: N · N photo(s)" line into a single narrow column.
const double _kMobileBreakpoint = 700;

class SellerProductsView extends StatefulWidget {
  final Store? store;
  const SellerProductsView({super.key, required this.store});

  @override
  State<SellerProductsView> createState() => _SellerProductsViewState();
}

class _SellerProductsViewState extends State<SellerProductsView> {
  final _productService = ProductService();
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SellerProductsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store?.id != widget.store?.id) _load();
  }

  Future<void> _load() async {
    if (widget.store == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    // includeHidden: true — this is the seller's own management view,
    // so hidden products must still show up (with a "Hidden" badge)
    // or there'd be no way to find and un-hide them again.
    final products = await _productService.getProducts(
      storeId: widget.store!.id,
      includeHidden: true,
    );
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  Future<void> _toggleVisibility(Product product) async {
    await _productService.updateProduct(product.id, isActive: !product.isActive);
    _load();
  }

  // Quick stock +/- straight from the product card — no need to open the
  void _openAddProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ProductFormSheet(storeId: widget.store!.id, onSaved: _load),
      ),
    );
  }

  void _openEditProductSheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ProductFormSheet(
          storeId: widget.store!.id,
          existingProduct: product,
          onSaved: _load,
        ),
      ),
    );
  }

  void _openManageImages(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ManageImagesSheet(product: product, onChanged: _load),
      ),
    );
  }

  String? _fullImageUrl(String? path) {
    if (path == null) return null;
    return '${ApiConfig.mediaBaseUrl}$path';
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.decimalPattern('en_US');

    if (widget.store == null) {
      return const Center(child: Text('Select or create a store first.'));
    }
    if (_loading) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _kMobileBreakpoint;

        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 16),
              if (_products.isEmpty) const Text('No products yet.'),
              ..._products.map((p) => _buildProductCard(p, priceFormat, isMobile)),
            ],
          ),
        );
      },
    );
  }

  // ---- Header: title + Add Product button. Stacks on mobile instead of
  // overflowing off the right edge. ----
  Widget _buildHeader(bool isMobile) {
    final title = Text(
      '${widget.store!.storeName} — Products',
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      overflow: TextOverflow.ellipsis,
      maxLines: isMobile ? 2 : 1,
    );
    final addButton = FilledButton.icon(
      onPressed: _openAddProductSheet,
      icon: const Icon(Icons.add),
      label: const Text('Add Product'),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 12),
          addButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: title),
        const SizedBox(width: 12),
        addButton,
      ],
    );
  }

  // ---- Product card: ListTile layout on wide screens (unchanged),
  // custom stacked layout on mobile so the subtitle line and action
  // icons both get enough room instead of being squeezed into one
  // vertical sliver. ----
  Widget _buildProductCard(Product p, NumberFormat priceFormat, bool isMobile) {
    final thumbUrl = p.imageUrls.isNotEmpty ? _fullImageUrl(p.imageUrls.first) : null;

    final thumb = SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: thumbUrl != null
            ? Image.network(thumbUrl, fit: BoxFit.cover)
            : Container(
                color: Colors.green.shade50,
                child: const Icon(Icons.image, color: Colors.green, size: 20),
              ),
      ),
    );

    final nameRow = Row(
      children: [
        Flexible(child: Text(p.nameLao, overflow: TextOverflow.ellipsis)),
        if (!p.isActive) ...[
          const SizedBox(width: 6),
          const Chip(
            label: Text('Hidden', style: TextStyle(fontSize: 11)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ],
    );

    final photoCountLine = Text(
      '${p.imageUrls.length} photo(s)',
      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
    );

    if (!isMobile) {
      // Unchanged desktop/web layout, with the stock adjuster added.
      return Opacity(
        opacity: p.isActive ? 1.0 : 0.55,
        child: Card(
          child: ListTile(
            leading: thumb,
            title: nameRow,
            subtitle: photoCountLine,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${priceFormat.format(p.basePrice)} ກີບ'),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit product',
                  onPressed: () => _openEditProductSheet(p),
                ),
                IconButton(
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  tooltip: 'Manage photos',
                  onPressed: () => _openManageImages(p),
                ),
                Switch(
                  value: p.isActive,
                  onChanged: (_) => _toggleVisibility(p),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ---- Mobile layout: image + name/photos on one row, stock
    // adjuster on its own row, price + action icons on the last row. ----
    return Opacity(
      opacity: p.isActive ? 1.0 : 0.55,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  thumb,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        nameRow,
                        const SizedBox(height: 4),
                        photoCountLine,
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${priceFormat.format(p.basePrice)} ກີບ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit product',
                    onPressed: () => _openEditProductSheet(p),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    tooltip: 'Manage photos',
                    onPressed: () => _openManageImages(p),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  Switch(
                    value: p.isActive,
                    onChanged: (_) => _toggleVisibility(p),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable strip of picked-but-not-yet-uploaded image thumbnails with
/// a remove (x) button on each — used while creating a new product.
class _PickedImagesStrip extends StatelessWidget {
  final List<Uint8List> images;
  final ValueChanged<int> onRemove;

  const _PickedImagesStrip({required this.images, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(images[index], width: 80, height: 80, fit: BoxFit.cover),
              ),
              Positioned(
                right: 2,
                top: 2,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  child: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Single sheet used for BOTH creating a new product and editing an
/// existing one. If [existingProduct] is null, it's create mode.
class _ProductFormSheet extends StatefulWidget {
  final int storeId;
  final Product? existingProduct;
  final VoidCallback onSaved;

  const _ProductFormSheet({
    required this.storeId,
    this.existingProduct,
    required this.onSaved,
  });

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _catalogService = CatalogService();
  final _productService = ProductService();
  final _uploadService = UploadService();
  final _imagePicker = ImagePicker();

  late final _nameCtrl = TextEditingController(text: widget.existingProduct?.nameLao ?? '');
  late final _descCtrl = TextEditingController(text: widget.existingProduct?.description ?? '');
  late final _priceCtrl = TextEditingController(
      text: widget.existingProduct != null ? widget.existingProduct!.basePrice.toStringAsFixed(0) : '');


  List<ProductCategory> _categories = [];
  List<ProductUnit> _units = [];
  int? _selectedCategoryId;
  int? _selectedUnitId;
  bool _loadingOptions = true;
  bool _submitting = false;
  bool _pickingImages = false;
  String? _error;

  final List<Uint8List> _pickedImages = [];

  bool get _isEditMode => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final categories = await _catalogService.getCategories();
    final units = await _catalogService.getUnits();
    setState(() {
      _categories = categories;
      _units = units;
      // Pre-select the existing product's category/unit when editing,
      // otherwise default to the first available option.
      _selectedCategoryId = widget.existingProduct != null
          ? widget.existingProduct!.categoryId
          : (categories.isNotEmpty ? categories.first.id : null);
      _selectedUnitId = widget.existingProduct != null
          ? widget.existingProduct!.unitId
          : (units.isNotEmpty ? units.first.id : null);
      _loadingOptions = false;
    });
  }

  Future<void> _pickImages() async {
    setState(() => _pickingImages = true);
    try {
      final picked = await _imagePicker.pickMultiImage();
      for (final file in picked) {
        final bytes = await file.readAsBytes();
        _pickedImages.add(compressImage(bytes, maxDimension: 1200, quality: 85));
      }
      setState(() {});
    } finally {
      setState(() => _pickingImages = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedCategoryId == null || _selectedUnitId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      Product product;
      if (_isEditMode) {
        // Stock is NOT edited here anymore — it's managed exclusively
        // on the Stock Summary page, where every change gets logged to
        // the stock history. Omitting stockQty means updateProduct()
        // won't touch it.
        product = await _productService.updateProduct(
          widget.existingProduct!.id,
          categoryId: _selectedCategoryId,
          unitId: _selectedUnitId,
          nameLao: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          basePrice: double.tryParse(_priceCtrl.text.trim()) ?? 0,
        );
      } else {
        // New products start at 0 stock — add stock via the Stock
        // Summary page once created.
        product = await _productService.createProduct(
          storeId: widget.storeId,
          categoryId: _selectedCategoryId!,
          unitId: _selectedUnitId!,
          nameLao: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          basePrice: double.tryParse(_priceCtrl.text.trim()) ?? 0,
        );
      }

      if (_pickedImages.isNotEmpty) {
        await _uploadService.uploadProductImages(
          productId: product.id,
          imagesBytes: _pickedImages,
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
      child: _loadingOptions
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_isEditMode ? 'Edit Product' : 'Add Product',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Product name (Lao)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description (details, freshness, origin, etc.)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration:
                        const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nameLao)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Price (LAK)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedUnitId,
                          decoration: const InputDecoration(
                              labelText: 'per', border: OutlineInputBorder()),
                          items: _units
                              .map((u) => DropdownMenuItem(
                                  value: u.id, child: Text(u.code)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedUnitId = v),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'e.g. select "g" to sell by the gram, "kg" by the kilogram, or "piece" for whole items',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isEditMode
                          ? 'Add more photos (${_pickedImages.length})'
                          : 'Photos (${_pickedImages.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PickedImagesStrip(
                    images: _pickedImages,
                    onRemove: (i) => setState(() => _pickedImages.removeAt(i)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickingImages ? null : _pickImages,
                    icon: _pickingImages
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_pickedImages.isEmpty ? 'Add photos' : 'Add more photos'),
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
                          ? const SizedBox(
                              height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_isEditMode ? 'Save changes' : 'Save product'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Sheet for adding/removing photos on an EXISTING product.
class _ManageImagesSheet extends StatefulWidget {
  final Product product;
  final VoidCallback onChanged;
  const _ManageImagesSheet({required this.product, required this.onChanged});

  @override
  State<_ManageImagesSheet> createState() => _ManageImagesSheetState();
}

class _ManageImagesSheetState extends State<_ManageImagesSheet> {
  final _uploadService = UploadService();
  final _imagePicker = ImagePicker();

  late List<ProductImageInfo> _images;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _images = List.of(widget.product.images);
  }

  String _fullUrl(String path) => '${ApiConfig.mediaBaseUrl}$path';

  Future<void> _addPhotos() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await _imagePicker.pickMultiImage();
      if (picked.isEmpty) return;

      final bytesList = <Uint8List>[];
      for (final file in picked) {
        final bytes = await file.readAsBytes();
        bytesList.add(compressImage(bytes, maxDimension: 1200, quality: 85));
      }

      final updated = await _uploadService.uploadProductImages(
        productId: widget.product.id,
        imagesBytes: bytesList,
      );
      setState(() => _images = updated.images);
      widget.onChanged();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto(ProductImageInfo image) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await _uploadService.deleteProductImage(image.id);
      setState(() => _images = updated.images);
      widget.onChanged();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${widget.product.nameLao} — Photos',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_images.isEmpty)
            const Text('No photos yet.')
          else
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final image = _images[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _fullUrl(image.imageUrl),
                          width: 90, height: 90, fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: GestureDetector(
                          onTap: _busy ? null : () => _removePhoto(image),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _addPhotos,
              icon: _busy
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add more photos'),
            ),
          ),
        ],
      ),
    );
  }
}
