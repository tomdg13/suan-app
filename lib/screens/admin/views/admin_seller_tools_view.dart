import 'package:flutter/material.dart';
import '../../../models/store.dart';
import '../../../services/store_service.dart';
import '../../seller/views/seller_store_profile_view.dart';
import '../../seller/views/seller_products_view.dart';
import '../../seller/views/seller_orders_view.dart';

/// Lets an admin do everything a seller can do (Store Profile, Products,
/// Orders) without leaving the admin panel. Reuses the same seller-facing
/// widgets so behavior/UI always stays in sync with the real seller flow.
///
/// Loads whichever store the admin account owns, exactly the way
/// SellerShellScreen does. If the admin account has no store yet,shows a
/// short message instead (there's no "create store" step here — that's
/// meant to happen via the normal seller onboarding flow).
class AdminSellerToolsView extends StatefulWidget {
  const AdminSellerToolsView({super.key});

  @override
  State<AdminSellerToolsView> createState() => _AdminSellerToolsViewState();
}

class _AdminSellerToolsViewState extends State<AdminSellerToolsView> {
  final _storeService = StoreService();

  int _selectedTab = 0;
  Store? _store;
  bool _loadingStore = true;

  static const _tabLabels = ['ໂປຣໄຟລ໌ຮ້ານ', 'ສິນຄ້າ', 'ຄໍາສັ່ງຊື້'];
  static const _tabIcons = [Icons.badge, Icons.inventory_2, Icons.receipt_long];

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    setState(() => _loadingStore = true);
    final stores = await _storeService.getMyStores();
    setState(() {
      _store = stores.isNotEmpty ? stores.first : null;
      _loadingStore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingStore) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_store == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'ບັນຊີແອັດມິນນີ້ຍັງບໍ່ມີຮ້ານຄ້າ.\n'
            'ຮ້ານຄ້າຈະຖືກສ້າງອັດຕະໂນມັດເມື່ອບັນຊີກາຍເປັນຜູ້ຂາຍ.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final views = [
      SellerStoreProfileView(
        store: _store,
        onStoreUpdated: (store) => setState(() => _store = store),
      ),
      SellerProductsView(store: _store),
      SellerOrdersView(store: _store),
    ];

    return Column(
      children: [
        Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: List.generate(_tabLabels.length, (i) {
                final selected = i == _selectedTab;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_tabLabels[i]),
                    avatar: Icon(_tabIcons[i], size: 18,
                        color: selected ? Colors.white : Colors.green),
                    selected: selected,
                    selectedColor: Colors.green,
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                    onSelected: (_) => setState(() => _selectedTab = i),
                  ),
                );
              }),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: IndexedStack(
            index: _selectedTab,
            children: views,
          ),
        ),
      ],
    );
  }
}
