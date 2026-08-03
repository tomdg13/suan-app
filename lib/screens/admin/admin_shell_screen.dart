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
import 'views/admin_seller_tools_view.dart';

// Below this width the permanent sidebar becomes a Drawer + bottom nav
// instead of squeezing the content panel. Same breakpoint used across
// the seller screens for consistency.
const double _kMobileBreakpoint = 700;

// Only these 4 sections get a spot on the bottom nav bar (9 items would be
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
    NavGroup(title: 'Dashboard', items: [
      NavItem(label: 'Overview', icon: Icons.dashboard, index: 0),
    ]),
    NavGroup(title: 'Content', items: [
      NavItem(label: 'Banners', icon: Icons.view_carousel, index: 1),
    ]),
    NavGroup(title: 'User Management', items: [
      NavItem(label: 'Users', icon: Icons.people, index: 2),
      NavItem(label: 'Roles', icon: Icons.badge, index: 3),
    ]),
    NavGroup(title: 'Store Management', items: [
      NavItem(label: 'Stores', icon: Icons.storefront, index: 4),
      NavItem(label: 'Applications', icon: Icons.assignment_turned_in, index: 5),
    ]),
    NavGroup(title: 'Orders', items: [
      NavItem(label: 'All Orders', icon: Icons.receipt_long, index: 6),
    ]),
    NavGroup(title: 'Finance', items: [
      NavItem(label: 'Withdrawals', icon: Icons.account_balance_wallet, index: 7),
    ]),
    // New: lets the admin operate a store the same way a seller does
    // (Store Profile, Products, Orders) without leaving the admin panel.
    NavGroup(title: 'Seller Tools', items: [
      NavItem(label: 'My Store', icon: Icons.storefront_outlined, index: 8),
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
  ];

  // Flat label lookup for the mobile AppBar title, keyed by the same
  // `index` values used in `_groups`.
  static const _titles = [
    'Overview',
    'Banners',
    'Users',
    'Roles',
    'Stores',
    'Applications',
    'All Orders',
    'Withdrawals',
    'My Store',
  ];

  static const _bottomNavItems = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Overview'),
    BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Stores'),
    BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
    BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Withdrawals'),
    BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
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
                  headerTitle: 'Admin Dashboard',
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
                headerTitle: 'Admin Dashboard',
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
