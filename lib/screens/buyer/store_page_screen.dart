import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../models/store.dart';
import '../../models/product.dart';
import '../../models/review.dart';
import '../../services/store_service.dart';
import '../../services/product_service.dart';
import '../../services/review_service.dart';
import '../../widgets/product_card.dart';
import 'product_detail_screen.dart';

/// Public-facing store page — what a buyer sees when they tap a store
/// (from a product's detail page, or the "Recommended Stores" row on
/// the home screen). Shows the store's branding, products, and reviews.
class StorePageScreen extends StatefulWidget {
  final int storeId;
  const StorePageScreen({super.key, required this.storeId});

  @override
  State<StorePageScreen> createState() => _StorePageScreenState();
}

class _StorePageScreenState extends State<StorePageScreen> with SingleTickerProviderStateMixin {
  final _storeService = StoreService();
  final _productService = ProductService();
  final _reviewService = ReviewService();
  late final TabController _tabController;

  Store? _store;
  List<Product> _products = [];
  List<Review> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _storeService.getStore(widget.storeId),
      _productService.getProducts(storeId: widget.storeId),
      _reviewService.getStoreReviews(widget.storeId),
    ]);
    setState(() {
      _store = results[0] as Store;
      _products = results[1] as List<Product>;
      _reviews = results[2] as List<Review>;
      _loading = false;
    });
  }

  String? _fullUrl(String? path) => path == null ? null : '${ApiConfig.mediaBaseUrl}$path';

  @override
  Widget build(BuildContext context) {
    if (_loading || _store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final store = _store!;
    final coverUrl = _fullUrl(store.coverUrl);
    final logoUrl = _fullUrl(store.logoUrl);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 190,
            pinned: true,
            backgroundColor: const Color(AppColors.primaryValue),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  coverUrl != null
                      ? Image.network(coverUrl, fit: BoxFit.cover)
                      : Container(color: const Color(AppColors.primaryValue)),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    right: 16,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          backgroundImage: logoUrl != null ? NetworkImage(logoUrl) : null,
                          child: logoUrl == null
                              ? const Icon(Icons.storefront, color: Color(AppColors.primaryValue))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      store.storeName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (store.isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, color: Colors.lightBlueAccent, size: 16),
                                  ],
                                ],
                              ),
                              Text(
                                '${store.province ?? ''}  •  ★ ${store.ratingAvg}  •  ${store.followerCount} followers',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'ສິນຄ້າ (${_products.length})'),
                Tab(text: 'ລີວິວ (${_reviews.length})'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildProductsTab(),
            _buildReviewsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTab() {
    if (_products.isEmpty) {
      return const Center(child: Text('No products yet'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _products.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.58,
      ),
      itemBuilder: (context, index) {
        final product = _products[index];
        return ProductCard(
          product: product,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id)),
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return const Center(child: Text('No reviews yet'));
    }
    final dateFormat = DateFormat('d MMM yyyy');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(AppColors.primaryValue).withValues(alpha: 0.15),
              child: Text(
                (review.userName?.isNotEmpty ?? false) ? review.userName![0].toUpperCase() : '?',
                style: const TextStyle(color: Color(AppColors.primaryValue)),
              ),
            ),
            title: Row(
              children: [
                Text(review.userName ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                ...List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 13,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (review.productName != null)
                  Text(review.productName!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                if (review.comment != null) Text(review.comment!),
                Text(dateFormat.format(review.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
        );
      },
    );
  }
}
