import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../utils/auth_guard.dart';
import 'store_page_screen.dart';
import 'fullscreen_gallery_screen.dart';
import 'buyer_payment_screen.dart';

// Maps the Lazada-style layout onto this app's real brand palette
// (AppColors from config/constants.dart) instead of Lazada's orange/red.
class _LazadaColors {
  static const primary = Color(AppColors.primaryValue); // brand green
  static const primaryDark = Color(AppColors.primaryValue);
  static const priceRed = Color(AppColors.primaryValue); // price uses brand green, not red
  static const star = Color(AppColors.warningValue); // amber, still reads as a rating star
  static const chipBorder = Color(AppColors.borderValue);
  static final chipSelectedBg = const Color(AppColors.accentValue).withOpacity(0.12);
  static const surface = Color(AppColors.backgroundValue);
  static const divider = Color(AppColors.borderValue);
  static const discount = Color(AppColors.errorValue); // strikethrough %-off badge only
}

// Below this width we stack the layout (image on top, info below) instead
// of side-by-side. Phones and narrow app windows fall under this; wide
// web/tablet views stay on the original two-column layout.
const double _kMobileBreakpoint = 700;

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _productService = ProductService();
  final _cartService = CartService();
  final _galleryController = PageController();

  Product? _product;
  ProductVariant? _selectedVariant;
  double _qty = 1;
  bool _loading = true;
  bool _adding = false;
  bool _buyingNow = false;
  int _galleryIndex = 0;

  // Available stock for whatever is currently selected — the chosen
  // variant's stock if one exists, otherwise the base product's stock.
  double get _maxQtyRaw => _selectedVariant?.stockQty ?? _product?.stockQty ?? 0;
  int get _maxQty => _maxQtyRaw.floor().clamp(0, 999999);
  String get _stockLabel =>
      _maxQtyRaw == _maxQtyRaw.roundToDouble() ? _maxQty.toString() : _maxQtyRaw.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final product = await _productService.getProduct(widget.productId);
    setState(() {
      _product = product;
      _selectedVariant = product.variants.isNotEmpty ? product.variants.first : null;
      _qty = _maxQty > 0 ? 1.0 : 0.0;
      _loading = false;
    });
  }

  Future<void> _addToCart() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn) return;
    if (!mounted) return;
    setState(() => _adding = true);
    try {
      await _cartService.addToCart(
        productId: widget.productId,
        variantId: _selectedVariant?.id,
        qty: _qty,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  // "Buy Now" — adds just this product to the cart, then jumps straight
  // into checkout so the user can pay for it without hunting through the
  // cart for other items. Reuses the same login guard as Add to Cart.
  Future<void> _buyNow() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn) return;
    if (!mounted) return;
    setState(() => _buyingNow = true);
    try {
      await _cartService.addToCart(
        productId: widget.productId,
        variantId: _selectedVariant?.id,
        qty: _qty,
      );
      if (!mounted) return;
      final price = _selectedVariant?.price ?? _product!.basePrice;
      // Backend adds a flat 20,000 ກີບ delivery fee per store at checkout
      // (DEFAULT_DELIVERY_FEE in orders.service.ts) — include it here so
      // the amount shown matches what checkout will actually charge.
      final total = (price * _qty) + 20000;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BuyerPaymentScreen(amount: total),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _buyingNow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _product == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _LazadaColors.primary)),
      );
    }

    final product = _product!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleSpacing: 0,
        title: Text(
          product.nameLao,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < _kMobileBreakpoint;
          return Padding(
            padding: const EdgeInsets.all(12),
            child: isMobile ? _buildMobileLayout(product) : _buildWebLayout(product),
          );
        },
      ),
    );
  }

  // ---- WEB / WIDE LAYOUT: gallery card on the left, info card on the right ----
  Widget _buildWebLayout(Product product) {
    final images = product.imageUrls;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 30,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _LazadaColors.divider),
            ),
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              child: _buildGallery(images),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 70,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _LazadaColors.divider),
            ),
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              child: _buildInfoColumn(product),
            ),
          ),
        ),
      ],
    );
  }

  // ---- MOBILE / NARROW LAYOUT: full-width gallery on top, info stacked below ----
  Widget _buildMobileLayout(Product product) {
    final images = product.imageUrls;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full-width gallery, no side squeeze.
          _buildGallery(images),
          const SizedBox(height: 16),
          _buildInfoColumn(product),
        ],
      ),
    );
  }

  // Shared info block (title, rating, price, store, options, qty, buttons,
  // description) used by both layouts so behavior stays identical.
  Widget _buildInfoColumn(Product product) {
    final priceFormat = NumberFormat.decimalPattern('en_US');
    final price = _selectedVariant?.price ?? product.basePrice;
    final hasDiscount = _selectedVariant != null && _selectedVariant!.price < product.basePrice;
    final discountPct = hasDiscount
        ? (((product.basePrice - _selectedVariant!.price) / product.basePrice) * 100).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          product.nameLao,
          style: const TextStyle(
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),

        // Rating row
        if (product.ratingCount > 0)
          Row(
            children: [
              _buildStarRow(product.ratingAvg),
              const SizedBox(width: 6),
              Text('${product.ratingAvg}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(width: 8),
              Container(width: 1, height: 12, color: _LazadaColors.divider),
              const SizedBox(width: 8),
              Text('${product.ratingCount} Reviews', style: const TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(width: 8),
              Container(width: 1, height: 12, color: _LazadaColors.divider),
              const SizedBox(width: 8),
              Text('${product.soldCount} Sold', style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ],
          ),
        const SizedBox(height: 12),

        // Price block
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _LazadaColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${priceFormat.format(price)} ກີບ',
                style: const TextStyle(
                  fontSize: 24,
                  color: _LazadaColors.priceRed,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              if (hasDiscount) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '${priceFormat.format(product.basePrice)} ກີບ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _LazadaColors.discount.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-$discountPct%',
                    style: const TextStyle(
                      color: _LazadaColors.discount,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Store row
        if (product.storeName != null) ...[
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => StorePageScreen(storeId: product.storeId)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _LazadaColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront, size: 16, color: _LazadaColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      product.storeName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.black45),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Options
        if (product.variants.isNotEmpty) ...[
          const Text('Options', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: product.variants.map((v) {
              final selected = v.id == _selectedVariant?.id;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedVariant = v;
                  _qty = _qty.clamp(_maxQty > 0 ? 1 : 0, _maxQty).toDouble();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? _LazadaColors.chipSelectedBg : Colors.white,
                    border: Border.all(
                      color: selected ? _LazadaColors.primary : _LazadaColors.chipBorder,
                      width: selected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    v.variantLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? _LazadaColors.primaryDark : Colors.black87,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Quantity
        Row(
          children: [
            const Text('Quantity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            const Spacer(),
            _buildQtyButton(
              icon: Icons.remove,
              onTap: () => setState(() => _qty = (_qty - 1).clamp(1, _maxQty).toDouble()),
            ),
            Container(
              width: 44,
              alignment: Alignment.center,
              child: Text('$_qty', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            _buildQtyButton(
              icon: Icons.add,
              onTap: () => setState(() => _qty = (_qty + 1).clamp(1, _maxQty).toDouble()),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            _maxQty <= 0 ? 'Out of stock' : '$_stockLabel left in stock',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _maxQty <= 0
                  ? const Color(AppColors.errorValue)
                  : (_maxQty <= 5 ? const Color(AppColors.warningValue) : Colors.grey.shade600),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Add to Cart + Buy Now, side by side
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _LazadaColors.priceRed,
                    side: const BorderSide(color: _LazadaColors.priceRed, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: (_adding || _buyingNow || _maxQty <= 0) ? null : _addToCart,
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: Text(
                    _adding ? 'Adding...' : (_maxQty <= 0 ? 'Out of Stock' : 'Add to Cart'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _LazadaColors.priceRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: (_adding || _buyingNow || _maxQty <= 0) ? null : _buyNow,
                  child: Text(
                    _buyingNow ? 'Processing...' : (_maxQty <= 0 ? 'Out of Stock' : 'Buy Now'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),

        if (product.description != null && product.description!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(height: 1, color: _LazadaColors.divider),
          const SizedBox(height: 16),
          const Text('Product Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(
            product.description!,
            style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
          ),
        ],
      ],
    );
  }

  Widget _buildStarRow(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (rating >= i + 1) {
          icon = Icons.star;
        } else if (rating > i && rating < i + 1) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, size: 15, color: _LazadaColors.star);
      }),
    );
  }

  Widget _buildQtyButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: _LazadaColors.chipBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }

  // Gallery: main image on top, thumbnail strip below. Now wrapped with a
  // Container that has NO fixed width constraint of its own — it simply
  // fills whatever parent gives it (full width on mobile, 30% flex on web),
  // so the AspectRatio always keeps the image square instead of being
  // squeezed into a sliver on narrow screens.
  Widget _buildGallery(List<String> images) {
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: _LazadaColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.image, size: 60, color: Colors.black26),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _LazadaColors.divider),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PageView.builder(
                    controller: _galleryController,
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _galleryIndex = i),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FullscreenGalleryScreen(images: images, initialIndex: index),
                          ),
                        ),
                        child: Image.network(
                          '${ApiConfig.mediaBaseUrl}${images[index]}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: _LazadaColors.surface,
                            child: const Icon(Icons.broken_image, size: 40, color: Colors.black26),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (images.length > 1)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_galleryIndex + 1}/${images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
          if (images.length > 1) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final active = index == _galleryIndex;
                  return GestureDetector(
                    onTap: () {
                      _galleryController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: active ? _LazadaColors.primary : _LazadaColors.chipBorder,
                          width: active ? 1.5 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        '${ApiConfig.mediaBaseUrl}${images[index]}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: _LazadaColors.surface,
                          child: const Icon(Icons.broken_image, size: 20, color: Colors.black26),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
