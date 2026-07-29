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

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _selected = 0;

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
  ];

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
          Expanded(
            child: IndexedStack(
              index: _selected,
              children: _views,
            ),
          ),
        ],
      ),
    );
  }
}
