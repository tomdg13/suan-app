import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/banner_item.dart';
import '../../models/store.dart';
import '../../services/catalog_service.dart';
import '../../services/product_service.dart';
import '../../services/banner_service.dart';
import '../../services/store_service.dart';
import '../../widgets/product_card.dart';
import '../../widgets/store_card.dart';
import '../../state/app_state.dart';
import '../../utils/auth_guard.dart';
import '../../utils/category_style.dart';
import '../auth/login_screen.dart';
import '../admin/admin_shell_screen.dart';
import '../seller/seller_shell_screen.dart';
import 'product_detail_screen.dart';
import 'store_page_screen.dart';
import 'cart_screen.dart';
import 'my_orders_screen.dart';

/// Public storefront — this is the app's home screen. Anyone can browse
/// categories and products without logging in. Login is only triggered
/// when they try to do something account-specific (view cart, view
/// orders, tap the account icon, or add something to cart).
class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  final _catalogService = CatalogService();
  final _productService = ProductService();
  final _bannerService = BannerService();
  final _storeService = StoreService();
  final _searchCtrl = TextEditingController();
  final _bannerController = PageController();

  List<ProductCategory> _categories = [];
  List<Product> _products = [];
  List<BannerItem> _banners = [];
  List<Store> _featuredStores = [];
  int _bannerIndex = 0;
  int? _selectedCategoryId;
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
      final categories = await _catalogService.getCategories();
      final products = await _productService.getProducts(
        categoryId: _selectedCategoryId,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
      final banners = await _bannerService.getActiveBanners();
      final featuredStores = await _storeService.getStores(featuredOnly: true);
      setState(() {
        _categories = categories;
        _products = products;
        _banners = banners;
        _featuredStores = featuredStores;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openCart() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  Future<void> _openOrders() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyOrdersScreen()));
  }

  /// Account icon: if not logged in -> go to login. If logged in ->
  /// route to whatever makes sense for that account's role.
  Future<void> _onAccountTap() async {
    final appState = context.read<AppState>();
    if (!appState.isLoggedIn) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (mounted) setState(() {}); // refresh app bar icon state
      return;
    }
    final role = appState.currentUser?.role;
    if (role == 'admin') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminShellScreen()));
    } else if (role == 'seller') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SellerShellScreen()));
    } else {
      _showAccountSheet();
    }
  }

  void _showAccountSheet() {
    final appState = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(appState.currentUser?.fullName ?? ''),
              subtitle: Text(appState.currentUser?.phone ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('My Orders'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyOrdersScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await appState.logout();
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(appState)),
            SliverToBoxAdapter(child: _buildBanner()),
            SliverToBoxAdapter(child: _buildCategoryRow()),
            SliverToBoxAdapter(child: _buildRecommendedStores()),
            SliverToBoxAdapter(child: _buildBestSellers()),
            SliverToBoxAdapter(child: _buildSectionTitle()),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('Error: $_error')),
                ),
              )
            else if (_products.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No products found')),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = _products[index];
                      return ProductCard(
                        product: product,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(productId: product.id),
                          ),
                        ),
                      );
                    },
                    childCount: _products.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppState appState) {
    return Container(
      color: const Color(AppColors.primaryValue),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'ສວນມັວກອມ Market',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(appState.isLoggedIn ? Icons.account_circle : Icons.login,
                      color: Colors.white),
                  tooltip: appState.isLoggedIn ? 'Account' : 'Login',
                  onPressed: _onAccountTap,
                ),
                IconButton(
                  icon: const Icon(Icons.receipt_long, color: Colors.white),
                  onPressed: _openOrders,
                ),
                IconButton(
                  icon: const Icon(Icons.shopping_cart, color: Colors.white),
                  onPressed: _openCart,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Signature search pill — sits inside the brand-color header,
            // the way the big regional marketplace apps anchor their home screen.
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'ຄົ້ນຫາສິນຄ້າ, ຮ້ານຄ້າ...',
                  hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    if (_banners.isEmpty) {
      // Fallback shown until an admin uploads a real banner —
      // see Admin Dashboard > Banners.
      return _buildFallbackBanner();
    }

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _bannerIndex = i),
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      '${ApiConfig.mediaBaseUrl}${banner.imageUrl}',
                      fit: BoxFit.cover,
                    ),
                    if (banner.title != null || banner.subtitle != null)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (banner.title != null)
                              Text(
                                banner.title!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            if (banner.subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                banner.subtitle!,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_banners.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_banners.length, (i) {
              final active = i == _bannerIndex;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 10 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? const Color(AppColors.primaryValue) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      height: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(AppColors.freshValue), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ສົດຈາກຟາມ ທົ່ວປະເທດ',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'ສັ່ງງ່າຍ ສົ່ງໄວ ຈາກເກສດຕະກອນຈິງ',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.eco, color: Colors.white, size: 56),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _CategoryTile(
            label: 'ທັງໝົດ',
            icon: Icons.grid_view_rounded,
            selected: _selectedCategoryId == null,
            onTap: () {
              setState(() => _selectedCategoryId = null);
              _load();
            },
          ),
          ..._categories.map((c) {
            return _CategoryTile(
              label: c.nameLao,
              icon: categoryIcon(c.nameEn),
              selected: _selectedCategoryId == c.id,
              onTap: () {
                setState(() => _selectedCategoryId = c.id);
                _load();
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecommendedStores() {
    if (_featuredStores.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(Icons.recommend, size: 18, color: Color(AppColors.primaryValue)),
                SizedBox(width: 6),
                Text('ຮ້ານຄ້າແນະນຳ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(AppColors.textDarkValue))),
              ],
            ),
          ),
          SizedBox(
            height: 128,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _featuredStores.length,
              itemBuilder: (context, index) {
                final store = _featuredStores[index];
                return StoreCard(
                  store: store,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => StorePageScreen(storeId: store.id)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestSellers() {
    if (_products.isEmpty) return const SizedBox.shrink();
    final bestSellers = [..._products]..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    final topSellers = bestSellers.take(8).toList();
    if (topSellers.isEmpty || topSellers.first.soldCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(Icons.local_fire_department, size: 18, color: Color(AppColors.errorValue)),
                SizedBox(width: 6),
                Text('ສິນຄ້າຂາຍດີ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(AppColors.textDarkValue))),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: topSellers.length,
              itemBuilder: (context, index) {
                final product = topSellers[index];
                return SizedBox(
                  width: 150,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ProductCard(
                      product: product,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(Icons.storefront, size: 18, color: Color(AppColors.accentValue)),
          SizedBox(width: 6),
          Text(
            'ສິນຄ້າແນະນຳ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(AppColors.textDarkValue)),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: categoryTileColor(),
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: const Color(AppColors.primaryValue), width: 2)
                    : null,
              ),
              child: Icon(icon, color: const Color(AppColors.primaryValue), size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: selected ? const Color(AppColors.primaryValue) : Colors.grey.shade700,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
