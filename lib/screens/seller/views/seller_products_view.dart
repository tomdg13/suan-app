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
import '../../../services/logistics_provider_service.dart';
import '../../../services/shipping_tier_service.dart';
import '../../../utils/image_compress.dart';
import '../../../utils/thousands_formatter.dart';
// Below this width the header stacks (title above the button instead of
// side-by-side) and product cards switch to a compact layout thatdoesn't
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
  int _page = 1;
  int _limit = 10;
  int _total = 0;
  final _goToCtrl = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }
  @override
  void didUpdateWidget(covariant SellerProductsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store?.id != widget.store?.id) {
      _page = 1;
      _load();
    }
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
    final result = await _productService.getProductsPaged(
      storeId: widget.store!.id,
      includeHidden: true,
      page: _page,
      limit: _limit,
    );
    setState(() {
      _products = result.items;
      _total = result.total;
      _loading = false;
    });
  }
  void _goToPage(int page) {
    final maxPage = _total == 0 ? 1 : (_total / _limit).ceil();
    if (page < 1 || page > maxPage) return;
    setState(() => _page = page);
    _load();
  }
  void _changeLimit(int newLimit) {
    setState(() {
      _limit = newLimit;
      _page = 1;
    });
    _load();
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
      return const Center(child: Text('ກະລຸນາເລືອກ ຫຼື ສ້າງຮ້ານຄ້າກ່ອນ.'));
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
              if (_products.isEmpty) const Text('ຍັງບໍ່ມີສິນຄ້າ.'),
              ..._products.map((p) => _buildProductCard(p, priceFormat, isMobile)),
              if (_total > 0) _buildPaginationBar(),
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
      '${widget.store!.storeName} — ສິນຄ້າ',
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      overflow: TextOverflow.ellipsis,
      maxLines: isMobile ? 2 : 1,
    );
    final addButton = FilledButton.icon(
      onPressed: _openAddProductSheet,
      icon: const Icon(Icons.add),
      label: const Text('ເພີ່ມສິນຄ້າ'),
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
  // ---- Pagination bar: Total count, prev/next, page numbers with
  // truncation, N/page selector, and a "Go to" field. ----
  Widget _buildPaginationBar() {
    final maxPage = _total == 0 ? 1 : (_total / _limit).ceil();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text('ທັງໝົດ: $_total'),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _page > 1 ? () => _goToPage(_page - 1) : null,
          ),
          for (int i = 1; i <= maxPage; i++)
            if (i == 1 || i == maxPage || (i - _page).abs() <= 1)
              OutlinedButton(
                onPressed: () => _goToPage(i),
                style: OutlinedButton.styleFrom(
                  backgroundColor: i == _page ? Theme.of(context).colorScheme.primary : null,
                  foregroundColor: i == _page ? Colors.white : null,
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                child: Text('$i'),
              )
            else if (i == _page - 2 || i == _page + 2)
              const Text('...'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _page < maxPage ? () => _goToPage(_page + 1) : null,
          ),
          DropdownButton<int>(
            value: _limit,
            items: const [10, 20, 50, 100]
                .map((n) => DropdownMenuItem(value: n, child: Text('$n / ໜ້າ')))
                .toList(),
            onChanged: (v) {
              if (v != null) _changeLimit(v);
            },
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _goToCtrl,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'ໄປໜ້າ',
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (v) {
                final p = int.tryParse(v);
                if (p != null) _goToPage(p);
                _goToCtrl.clear();
              },
            ),
          ),
        ],
      ),
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
            label: Text('ຖືກເຊື່ອງ', style: TextStyle(fontSize: 11)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ],
    );
    final photoCountLine = Text(
      '${p.imageUrls.length} ຮູບ',
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
                  tooltip: 'ແກ້ໄຂສິນຄ້າ',
                  onPressed: () => _openEditProductSheet(p),
                ),
                IconButton(
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  tooltip: 'ຈັດການຮູບພາບ',
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
                    tooltip: 'ແກ້ໄຂສິນຄ້າ',
                    onPressed: () => _openEditProductSheet(p),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo_library_outlined,size: 20),
                    tooltip: 'ຈັດການຮູບພາບ',
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
/// Reusable strip of picked-but-not-yet-uploaded image thumbnailswith
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
  final _logisticsService = LogisticsProviderService();
  final _tierService = ShippingTierService();
  late final _nameCtrl = TextEditingController(text: widget.existingProduct?.nameLao ?? '');
  late final _descCtrl = TextEditingController(text: widget.existingProduct?.description ?? '');
  late final _priceCtrl = TextEditingController(
      text: widget.existingProduct != null
          ? NumberFormat.decimalPattern('en_US').format(widget.existingProduct!.basePrice)
          : '');
  late final _weightCtrl = TextEditingController(
      text: widget.existingProduct != null && widget.existingProduct!.weight > 0
          ? widget.existingProduct!.weight.toString()
          : '');
  late final _sizeCtrl = TextEditingController(
      text: widget.existingProduct != null && widget.existingProduct!.sizeCm > 0
          ? widget.existingProduct!.sizeCm.toString()
          : '');
  List<ProductCategory> _categories = [];
  List<ProductUnit> _units = [];
  List<LogisticsProvider> _providers = [];
  int? _selectedCategoryId;
  int? _selectedUnitId;
  int? _selectedProviderId;
  bool _loadingOptions = true;
  bool _submitting = false;
  bool _pickingImages = false;
  String? _error;
  final List<Uint8List> _pickedImages = [];
  // Shipping-fee preview state — recalculated whenever the selected
  // provider, weight, or size changes (only when the provider allows
  // seller-managed weight tiers; otherwise there's nothing to preview).
  List<ShippingTier> _providerTiers = [];
  bool _loadingTiers = false;
  bool get _isEditMode => widget.existingProduct != null;
  LogisticsProvider? get _selectedProvider => _selectedProviderId == null
      ? null
      : _providers.where((p) => p.id == _selectedProviderId).firstOrNull;
  @override
  void initState() {
    super.initState();
    _weightCtrl.addListener(() => setState(() {}));
    _sizeCtrl.addListener(() => setState(() {}));
    _loadOptions();
  }
  Future<void> _loadOptions() async {
    final categories = await _catalogService.getCategories();
    final units = await _catalogService.getUnits();
    final providers = await _logisticsService.fetchActive();
    setState(() {
      _categories = categories;
      _units = units;
      _providers = providers;
      // Pre-select the existing product's category/unit when editing,
      // otherwise default to the first available option.
      _selectedCategoryId = widget.existingProduct != null
          ? widget.existingProduct!.categoryId
          : (categories.isNotEmpty ? categories.first.id : null);
      _selectedUnitId = widget.existingProduct != null
          ? widget.existingProduct!.unitId
          : (units.isNotEmpty ? units.first.id : null);
      _selectedProviderId = widget.existingProduct?.providerId;
      _loadingOptions = false;
    });
    if (_selectedProviderId != null && (_selectedProvider?.allowWeightTiers ?? false)) {
      _loadTiersForProduct();
    }
  }
  Future<void> _loadTiersForProduct() async {
    if (widget.existingProduct?.id == null) {
      setState(() => _providerTiers = []);
      return;
    }
    setState(() => _loadingTiers = true);
    try {
      final tiers = await _tierService.fetchByProduct(widget.existingProduct!.id);
      setState(() => _providerTiers = tiers);
    } finally {
      setState(() => _loadingTiers = false);
    }
  }
  Future<void> _onProviderChanged(int? providerId) async {
    setState(() {
      _selectedProviderId = providerId;
      _providerTiers = [];
    });
    // In edit mode, persist the provider choice immediately - tiers
    // need providerId already saved on the product row before they can
    // be attached, and waiting for the full form submit would leave
    // the "ເພີ່ມຂັ້ນ" button broken until the seller saves first.
    if (_isEditMode && providerId != null) {
      try {
        await _productService.updateProduct(widget.existingProduct!.id, providerId: providerId);
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
    }
    final provider = _selectedProvider;
    if (_isEditMode && provider != null && provider.allowWeightTiers) {
      _loadTiersForProduct();
    }
  }
  // Opens a small form to add ONE tier (metric + threshold + price) for
  // the currently selected provider. Reopens are just another tap of
  // the same button, so the seller can add several tiers in a row
  // without leaving the product form.
  Future<void> _openAddTierDialog() async {
    final productId = widget.existingProduct?.id;
    if (productId == null || _selectedProviderId == null) return;
    final metricCtrl = ValueNotifier<String>('weight');
    final minCtrl = TextEditingController();
    final maxCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String? dialogError;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('ເພີ່ມຂັ້ນຄ່າສົ່ງ'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ຄິດໄລ່ຈາກ', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<String>(
                    valueListenable: metricCtrl,
                    builder: (_, metric, __) => SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'weight', label: Text('ນ້ຳໜັກ (ກິໂລ)')),
                        ButtonSegment(value: 'size', label: Text('ຂະໜາດ (ຊມ)')),
                      ],
                      selected: {metric},
                      onSelectionChanged: (s) => metricCtrl.value = s.first,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'ຈາກ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: maxCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'ຫາ (ວ່າງ = ຂຶ້ນໄປ)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'ຄ່າສົ່ງ (ກີບ)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(dialogError!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('ປິດ'),
              ),
              FilledButton(
                onPressed: () async {
                  final min = double.tryParse(minCtrl.text.trim());
                  final max = maxCtrl.text.trim().isEmpty ? null : double.tryParse(maxCtrl.text.trim());
                  final price = int.tryParse(ThousandsInputFormatter.unformat(priceCtrl.text.trim()));
                  if (min == null || min < 0) {
                    setDialogState(() => dialogError = 'ກະລຸນາໃສ່ຄ່າ "ຈາກ" ໃຫ້ຖືກຕ້ອງ');
                    return;
                  }
                  if (price == null || price < 0) {
                    setDialogState(() => dialogError = 'ກະລຸນາໃສ່ຄ່າສົ່ງໃຫ້ຖືກຕ້ອງ');
                    return;
                  }
                  try {
                    await _tierService.create(
                      productId: productId,
                      metric: metricCtrl.value,
                      minWeight: min,
                      maxWeight: max,
                      price: price,
                      sortOrder: _providerTiers.length,
                    );
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                    // Clear inputs so the same dialog starts fresh if
                    // the seller taps "ເພີ່ມຂັ້ນ" again right away.
                    minCtrl.clear();
                    maxCtrl.clear();
                    priceCtrl.clear();
                    await _loadTiersForProduct();
                  } on ApiException catch (e) {
                    setDialogState(() => dialogError = e.message);
                  }
                },
                child: const Text('ບັນທຶກຂັ້ນ'),
              ),
            ],
          );
        },
      ),
    );
  }
  Future<void> _deleteTier(ShippingTier tier) async {
    try {
      await _tierService.delete(tier.id);
      await _loadTiersForProduct();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
  Future<void> _pickImages() async {
    setState(() => _pickingImages = true);
    try {
      final picked = await _imagePicker.pickMultiImage();
      for (final file in picked) {
        final bytes = await file.readAsBytes();
        _pickedImages.add(compressImage(bytes, maxDimension: 1200,quality: 85));
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
          providerId: _selectedProviderId,
          nameLao: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          basePrice: double.tryParse(ThousandsInputFormatter.unformat(_priceCtrl.text.trim())) ?? 0,
          weight: double.tryParse(_weightCtrl.text.trim()) ?? 0,
          sizeCm: double.tryParse(_sizeCtrl.text.trim()) ?? 0,
        );
      } else {
        // New products start at 0 stock — add stock via the Stock
        // Summary page once created.
        product = await _productService.createProduct(
          storeId: widget.storeId,
          categoryId: _selectedCategoryId!,
          unitId: _selectedUnitId!,
          providerId: _selectedProviderId,
          nameLao: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          basePrice: double.tryParse(ThousandsInputFormatter.unformat(_priceCtrl.text.trim())) ?? 0,
          weight: double.tryParse(_weightCtrl.text.trim()) ?? 0,
          sizeCm: double.tryParse(_sizeCtrl.text.trim()) ?? 0,
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
  String _tierRangeLabel(ShippingTier tier) {
    final unit = tier.metric == 'size' ? 'ຊມ' : 'ກິໂລ';
    String fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    if (tier.maxWeight == null) return '${fmt(tier.minWeight)}+ $unit';
    return '${fmt(tier.minWeight)} - ${fmt(tier.maxWeight!)} $unit';
  }
  // ---- Shipping section: provider dropdown + conditional content
  // below it depending on the selected provider's type. ----
  Widget _buildShippingSection() {
    final provider = _selectedProvider;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ວິທີການຈັດສົ່ງ', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _selectedProviderId,
          decoration: const InputDecoration(
            labelText: 'ຜູ້ໃຫ້ບໍລິການຂົນສົ່ງ',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<int>(value: null, child: Text('— ບໍ່ລະບຸ —')),
            for (final p in _providers)
              DropdownMenuItem(value: p.id, child: Text(p.name)),
          ],
          onChanged: _onProviderChanged,
        ),
        const SizedBox(height: 8),
        if (provider == null)
          Text(
            'ຖ້າບໍ່ເລືອກ, ຄ່າສົ່ງຈະຄິດຕາມການຕັ້ງຄ່າເລີ່ມຕົ້ນຂອງລະບົບ.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          )
        else if (provider.allowWeightTiers)
          _buildWeightTierSection()
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              provider.type == 'store_pickup'
                  ? 'ຮັບເອງທີ່ຮ້ານ — ບໍ່ມີຄ່າສົ່ງ.'
                  : 'ຄ່າສົ່ງຈະຄິດໄລ່ໂດຍບໍລິສັດຂົນສົ່ງນີ້ໂດຍກົງ (ບໍ່ຕ້ອງຕັ້ງນ້ຳໜັກ/ຂະໜາດ).',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
            ),
          ),
      ],
    );
  }
  // Weight/size inputs + live fee preview + tier management — only
  // shown for providers where the admin has enabled allow_weight_tiers.
  Widget _buildWeightTierSection() {
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0;
    final size = double.tryParse(_sizeCtrl.text.trim()) ?? 0;
    final hasTiers = _providerTiers.isNotEmpty;
    final previewFee = hasTiers
        ? ShippingTierService.priceForValues(_providerTiers, weightKg: weight, sizeCm: size)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ນ້ຳໜັກ ແລະ ຂະໜາດຕົວຈິງຂອງສິນຄ້ານີ້',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: Text(
            'ໃສ່ນ້ຳໜັກ/ຂະໜາດຕົວຈິງຂອງສິນຄ້າ (ບໍ່ແມ່ນລາຄາຄ່າສົ່ງ) — ຈະຖືກນຳໄປທຽບກັບຂັ້ນຄ່າສົ່ງດ້ານລຸ່ມ ເພື່ອຄິດຄ່າສົ່ງໃຫ້ອັດຕະໂນມັດ.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'ນ້ຳໜັກ (ກິໂລ)',
                  hintText: '0.5, 1, 2.5',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _sizeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'ຂະໜາດ (ຊມ)',
                  hintText: 'ຖ້າມີ',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingTiers)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (!hasTiers)
          Text(
            'ຜູ້ໃຫ້ບໍລິການນີ້ຍັງບໍ່ໄດ້ຕັ້ງລະດັບຄ່າສົ່ງ — ກົດ "ເພີ່ມຂັ້ນ" ດ້ານລຸ່ມເພື່ອຕັ້ງ.',
            style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'ຄ່າສົ່ງໂດຍປະມານ: ${NumberFormat.decimalPattern('en_US').format(previewFee ?? 0)} ກີບ',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
            ),
          ),
          const SizedBox(height: 8),
          ...(_providerTiers..sort((a, b) => a.minWeight.compareTo(b.minWeight))).map(
            (tier) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    tier.metric == 'size' ? Icons.straighten : Icons.scale,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_tierRangeLabel(tier)} — ${NumberFormat.decimalPattern('en_US').format(tier.price)} ກີບ',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  InkWell(
                    onTap: () => _deleteTier(tier),
                    child: Icon(Icons.close, size: 14, color: Colors.red.shade400),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _openAddTierDialog,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('ເພີ່ມຂັ້ນ', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
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
                  Text(_isEditMode ? 'ແກ້ໄຂສິນຄ້າ' : 'ເພີ່ມສິນຄ້າ',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'ຊື່ສິນຄ້າ (ພາສາລາວ)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ລາຍລະອຽດ (ຄຸນນະພາບ, ຄວາມສົດ, ແຫຼ່ງທີ່ມາ ແລະ ອື່ນໆ)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration:
                        const InputDecoration(labelText: 'ໝວດໝູ່', border: OutlineInputBorder()),
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
                          inputFormatters: [ThousandsInputFormatter()],
                          decoration: const InputDecoration(
                              labelText: 'ລາຄາ (ກີບ)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedUnitId,
                          decoration: const InputDecoration(
                              labelText: 'ຕໍ່', border: OutlineInputBorder()),
                          items: _units
                              .map((u) => DropdownMenuItem(
                                  value: u.id, child: Text(u.nameLao)))
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
                        'ຕົວຢ່າງ: ເລືອກ "g" ເພື່ອຂາຍເປັນກຣາມ, "kg" ເປັນກິໂລ, ຫຼື "piece" ສຳລັບຂາຍເປັນຫົວ/ອັນ',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildShippingSection(),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isEditMode
                          ? 'ເພີ່ມຮູບເພີ່ມເຕີມ (${_pickedImages.length})'
                          : 'ຮູບພາບ (${_pickedImages.length})',
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
                    label: Text(_pickedImages.isEmpty ? 'ເພີ່ມຮູບພາບ' : 'ເພີ່ມຮູບອື່ນ'),
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
                          : Text(_isEditMode ? 'ບັນທຶກການປ່ຽນແປງ' : 'ບັນທຶກສິນຄ້າ'),
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
          Text('${widget.product.nameLao} — ຮູບພາບ',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_images.isEmpty)
            const Text('ຍັງບໍ່ມີຮູບພາບ.')
          else
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width:8),
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
              label: const Text('ເພີ່ມຮູບອື່ນ'),
            ),
          ),
        ],
      ),
    );
  }
}
