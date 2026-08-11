import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/store.dart';
import '../../services/store_service.dart';
import '../../state/app_state.dart';
import '../../widgets/side_nav.dart';
import '../buyer/buyer_home_screen.dart';
import 'views/seller_store_profile_view.dart';
import 'views/seller_products_view.dart';
import 'views/seller_orders_view.dart';
import 'views/seller_stock_summary_screen.dart';

// Below this width, the permanent sidebar becomes a Drawer (hamburger menu)
// instead of squeezing the content panel. Matches the breakpoint used on
// the product detail screen for consistency.
const double _kMobileBreakpoint = 700;

class SellerShellScreen extends StatefulWidget {
  const SellerShellScreen({super.key});
  @override
  State<SellerShellScreen> createState() => _SellerShellScreenState();
}

class _SellerShellScreenState extends State<SellerShellScreen> {
  final _storeService = StoreService();
  int _selected = 0;
  Store? _selectedStore;
  bool _loadingStore = true;

  static const _groups = [
    NavGroup(title: 'My Store', items: [
      NavItem(label: 'Store Profile', icon: Icons.badge, index: 0),
    ]),
    NavGroup(title: 'Management', items: [
      NavItem(label: 'Products', icon: Icons.inventory_2, index: 1),
      NavItem(label: 'Stock Summary', icon: Icons.bar_chart, index: 3),
      NavItem(label: 'Orders', icon: Icons.receipt_long, index: 2),
    ]),
  ];

  // Labels for the bottom nav bar (mobile only). Stock Summary isn't
  // pinned here (4 items is already the practical max before it feels
  // cramped) — it's still reachable via the Drawer.
  static const _bottomNavItems = [
    BottomNavigationBarItem(icon: Icon(Icons.badge), label: 'Store'),
    BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Products'),
    BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
  ];
  static const _bottomNavIndices = [0, 1, 2]; // maps bottom-bar position -> _selected index

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  // Stores are now auto-created on becoming a seller, so the shell just
  // loads whichever one they own on open — no manual "create/switch"
  // step needed for the common single-store case.
  Future<void> _loadStore() async {
    setState(() => _loadingStore = true);
    final stores = await _storeService.getMyStores();
    setState(() {
      _selectedStore = stores.isNotEmpty ? stores.first : null;
      _loadingStore = false;
    });
  }

  Future<void> _logout() async {
    await context.read<AppState>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BuyerHomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final views = [
      SellerStoreProfileView(
        store: _selectedStore,
        onStoreUpdated: (store) => setState(() => _selectedStore = store),
      ),
      SellerProductsView(store: _selectedStore),
      SellerOrdersView(store: _selectedStore),
      _selectedStore != null
          ? SellerStockSummaryScreen(store: _selectedStore!)
          : const Center(child: Text('Select or create a store first.')),
    ];

    final content = _loadingStore
        ? const Center(child: CircularProgressIndicator())
        : IndexedStack(
            index: _selected,
            children: views,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _kMobileBreakpoint;

        if (isMobile) {
          // ---- MOBILE: sidebar moves into a Drawer, content gets full width,
          // and a bottom nav bar gives quick access without opening the drawer.
          final bottomNavPosition = _bottomNavIndices.contains(_selected)
              ? _bottomNavIndices.indexOf(_selected)
              : 0;

          return Scaffold(
            appBar: AppBar(
              title: Text(_selectedStore?.storeName ?? 'Seller Panel'),
            ),
            drawer: Drawer(
              child: SafeArea(
                child: SideNav(
                  groups: _groups,
                  selectedIndex: _selected,
                  onSelect: (i) {
                    setState(() => _selected = i);
                    Navigator.of(context).pop(); // close drawer after picking
                  },
                  headerTitle: _selectedStore?.storeName ?? 'Seller Panel',
                  headerIcon: Icons.storefront,
                  onLogout: _logout,
                ),
              ),
            ),
            body: content,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: bottomNavPosition,
              onTap: (i) => setState(() => _selected = _bottomNavIndices[i]),
              items: _bottomNavItems,
              type: BottomNavigationBarType.fixed,
            ),
          );
        }

        // ---- WEB / WIDE: original permanent sidebar layout ----
        return Scaffold(
          body: Row(
            children: [
              SideNav(
                groups: _groups,
                selectedIndex: _selected,
                onSelect: (i) => setState(() => _selected = i),
                headerTitle: _selectedStore?.storeName ?? 'Seller Panel',
                headerIcon: Icons.storefront,
                onLogout: _logout,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}
