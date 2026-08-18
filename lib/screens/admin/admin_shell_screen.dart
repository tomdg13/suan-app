import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../widgets/side_nav.dart';
import '../buyer/buyer_home_screen.dart';
import 'views/admin_overview_view.dart';
import 'views/admin_users_view.dart';
import 'views/admin_roles_view.dart';
import 'views/admin_stores_view.dart';
import 'views/admin_applications_view.dart';
import 'views/admin_orders_view.dart';
import 'views/admin_withdrawals_view.dart';
import 'views/admin_banners_view.dart';
import 'views/admin_categories_view.dart';
import 'views/admin_seller_tools_view.dart';
import 'views/admin_payment_confirmations_view.dart';
import 'views/admin_fee_configs_view.dart';
import 'views/admin_shipping_tiers_view.dart';
import 'views/admin_content_view.dart';
import 'views/admin_logistics_providers_view.dart';
import 'admin_payment_qr_upload_screen.dart';

// Below this width the permanent sidebar becomes a Drawer + bottom nav
// instead of squeezing the content panel. Same breakpoint used across
// the seller screens for consistency.
const double _kMobileBreakpoint = 700;

// Only these 4 sections get a spot on the bottom nav bar (9 itemswould be
// too cramped/unreadable). Everything else stays reachable via "More",
// which opens the same Drawer used for the full nav list.
const List<int> _bottomNavIndices = [0, 4, 6, 7]; // Overview, Stores, All Orders, Withdrawals
const int _moreTabPosition = 4; // last slot on the bottom bar

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _selected = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _groups = [
    NavGroup(title: 'ໜ້າຫຼັກ', items: [
      NavItem(label: 'ພາບລວມ', icon: Icons.dashboard, index: 0),
    ]),
    NavGroup(title: 'ເນື້ອຫາ', items: [
      NavItem(label: 'ແບນເນີ', icon: Icons.view_carousel, index: 1),
      NavItem(label: 'ໝວດໝູ່', icon: Icons.category, index: 12),
      NavItem(label: 'ຂໍ້ຄວາມ', icon: Icons.text_fields, index: 13),
      NavItem(label: 'ວິທີການຈັດສົ່ງ', icon: Icons.local_shipping, index: 14),
    ]),
    NavGroup(title: 'ຈັດການຜູ້ໃຊ້', items: [
      NavItem(label: 'ຜູ້ໃຊ້', icon: Icons.people, index: 2),
      NavItem(label: 'ບົດບາດ', icon: Icons.badge, index: 3),
    ]),
    NavGroup(title: 'ຈັດການຮ້ານຄ້າ', items: [
      NavItem(label: 'ຮ້ານຄ້າ', icon: Icons.storefront, index: 4),
      NavItem(label: 'ຄຳຮ້ອງສະໝັກ', icon: Icons.assignment_turned_in, index: 5),
    ]),
    NavGroup(title: 'ຄໍາສັ່ງຊື້', items: [
      NavItem(label: 'ຄໍາສັ່ງຊື້ທັງໝົດ', icon: Icons.receipt_long, index: 6),
    ]),
    NavGroup(title: 'ການເງິນ', items: [
      NavItem(label: 'ຖອນເງິນ', icon: Icons.account_balance_wallet, index: 7),
      NavItem(label: 'QR ຊຳລະເງິນ', icon: Icons.qr_code, index: 9),
      NavItem(label: 'ຢືນຢັນການຊຳລະເງິນ', icon: Icons.fact_check, index: 10),
      NavItem(label: 'ຄ່າທຳນຽມ', icon: Icons.receipt_long_outlined, index: 11),
      NavItem(label: 'ຄ່າຂົນສົງ', icon: Icons.local_shipping_outlined, index: 15),
    ]),
    // New: lets the admin operate a store the same way a seller does
    // (Store Profile, Products, Orders) without leaving the adminpanel.
    NavGroup(title: 'ເຄື່ອງມືຮ້ານຄ້າ', items: [
      NavItem(label: 'ຮ້ານຂອງຂ້ອຍ', icon: Icons.storefront_outlined, index: 8),
    ]),
  ];

  static const _views = [
    AdminOverviewView(),
    AdminBannersView(),
    AdminUsersView(),
    AdminRolesView(),
    AdminStoresView(),
    AdminApplicationsView(),
    AdminOrdersView(),
    AdminWithdrawalsView(),
    AdminSellerToolsView(),
    AdminPaymentQrUploadScreen(),
    AdminPaymentConfirmationsView(),
    AdminFeeConfigsView(),
    const AdminCategoriesView(),
    const AdminContentView(),
    const AdminLogisticsProvidersView(),
    const AdminShippingTiersView(),
  ];

  // Flat label lookup for the mobile AppBar title, keyed by the same
  // `index` values used in `_groups`.
  static const _titles = [
    'ພາບລວມ',
    'ແບນເນີ',
    'ຜູ້ໃຊ້',
    'ບົດບາດ',
    'ຮ້ານຄ້າ',
    'ຄຳຮ້ອງສະໝັກ',
    'ຄໍາສັ່ງຊື້ທັງໝົດ',
    'ຖອນເງິນ',
    'ຮ້ານຂອງຂ້ອຍ',
    'QR ຊຳລະເງິນ',
    'ຢືນຢັນການຊຳລະເງິນ',
    'ຄ່າທຳນຽມ',
    'ໝວດໝູ່ສິນຄ້າ',
    'ຂໍ້ຄວາມ',
    'ວິທີການຈັດສົ່ງ',
    'ຄ່າຂົນສົງ',
  ];

  static const _bottomNavItems = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'ພາບລວມ'),
    BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'ຮ້ານຄ້າ'),
    BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'ຄໍາສັ່ງຊື້'),
    BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'ຖອນເງິນ'),
    BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'ອື່ນໆ'),
  ];

  Future<void> _logout() async {
    await context.read<AppState>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BuyerHomeScreen()),
      (route) => false,
    );
  }

  void _onBottomNavTap(int tappedPosition) {
    if (tappedPosition == _moreTabPosition) {
      // "More" doesn't switch content itself — it opens the drawer so
      // the person can pick any of the remaining sections (including
      // the new "My Store" seller tools).
      _scaffoldKey.currentState?.openDrawer();
      return;
    }
    setState(() => _selected = _bottomNavIndices[tappedPosition]);
  }

  @override
  Widget build(BuildContext context) {
    final content = IndexedStack(
      index: _selected,
      children: _views,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _kMobileBreakpoint;

        if (isMobile) {
          // If the currently selected section isn't one of the 4 pinned
          // to the bottom bar, highlight "More" instead of nothing.
          final bottomNavPosition = _bottomNavIndices.contains(_selected)
              ? _bottomNavIndices.indexOf(_selected)
              : _moreTabPosition;

          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              title: Text(_titles[_selected]),
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
                  headerTitle: 'ແຜງຄວບຄຸມແອັດມິນ',
                  headerIcon: Icons.admin_panel_settings,
                  onLogout: _logout,
                ),
              ),
            ),
            body: content,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: bottomNavPosition,
              onTap: _onBottomNavTap,
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
                headerTitle: 'ແຜງຄວບຄຸມແອັດມິນ',
                headerIcon: Icons.admin_panel_settings,
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
