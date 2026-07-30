import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../utils/auth_guard.dart';
import 'store_page_screen.dart';

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
  int _galleryIndex = 0;

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
      setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.decimalPattern('en_US');

    if (_loading || _product == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final product = _product!;
    final price = _selectedVariant?.price ?? product.basePrice;
    final images = product.imageUrls;

    return Scaffold(
      appBar: AppBar(title: Text(product.nameLao)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGallery(images),
          const SizedBox(height: 16),
          Text(product.nameLao, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (product.storeName != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => StorePageScreen(storeId: product.storeId)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('ຮ້ານ: ${product.storeName}',
                      style: TextStyle(color: const Color(AppColors.primaryValue), decoration: TextDecoration.underline)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text('${priceFormat.format(price)} ກີບ',
              style: const TextStyle(fontSize: 22, color: Colors.orange, fontWeight: FontWeight.bold)),
          if (product.ratingCount > 0)
            Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                Text(' ${product.ratingAvg} (${product.ratingCount} reviews)  •  ${product.soldCount} sold'),
              ],
            ),
          const SizedBox(height: 16),
          if (product.description != null && product.description!.isNotEmpty) ...[
            Text(product.description!),
            const SizedBox(height: 16),
          ],
          if (product.variants.isNotEmpty) ...[
            const Text('Options', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: product.variants.map((v) {
                final selected = v.id == _selectedVariant?.id;
                return ChoiceChip(
                  label: Text(v.variantLabel),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedVariant = v),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              const Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() => _qty = (_qty - 1).clamp(1, 999)),
              ),
              Text('$_qty', style: const TextStyle(fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _qty += 1),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _adding ? null : _addToCart,
              icon: const Icon(Icons.shopping_cart),
              label: Text(_adding ? 'Adding...' : 'Add to cart'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGallery(List<String> images) {
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1.4,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.image, size: 60, color: Colors.green),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: PageView.builder(
              controller: _galleryController,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _galleryIndex = i),
              itemBuilder: (context, index) {
                return Image.network(
                  '${ApiConfig.mediaBaseUrl}${images[index]}',
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (i) {
              final active = i == _galleryIndex;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 10 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? Colors.green : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
