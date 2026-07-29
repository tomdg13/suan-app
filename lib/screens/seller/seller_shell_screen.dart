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
      NavItem(label: 'Orders', icon: Icons.receipt_long, index: 2),
    ]),
  ];

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
    ];

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
          Expanded(
            child: _loadingStore
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _selected,
                    children: views,
                  ),
          ),
        ],
      ),
    );
  }
}
