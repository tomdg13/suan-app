import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../state/app_state.dart';
import 'my_orders_screen.dart';

class BuyerProfileScreen extends StatelessWidget {
  const BuyerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

    return Scaffold(
      backgroundColor: const Color(AppColors.backgroundValue),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Header: avatar, name, phone ----
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(AppColors.primaryValue).withOpacity(0.12),
                      child: const Icon(Icons.person, size: 32, color: Color(AppColors.primaryValue)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? '',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(AppColors.textDarkValue)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.phone ?? '',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ---- My Orders section ----
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'My Orders',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(AppColors.textDarkValue)),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                          ),
                          child: Row(
                            children: [
                              Text('View All Orders', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade600),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _OrderStatusIcon(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'To Pay',
                          onTap: () => _openOrders(context, OrderStatusFilter.toPay),
                        ),
                        _OrderStatusIcon(
                          icon: Icons.inventory_2_outlined,
                          label: 'To Ship',
                          onTap: () => _openOrders(context, OrderStatusFilter.toShip),
                        ),
                        _OrderStatusIcon(
                          icon: Icons.local_shipping_outlined,
                          label: 'To Receive',
                          onTap: () => _openOrders(context, OrderStatusFilter.toReceive),
                        ),
                        _OrderStatusIcon(
                          icon: Icons.rate_review_outlined,
                          label: 'To Review',
                          onTap: () => _openOrders(context, OrderStatusFilter.toReview),
                        ),
                        _OrderStatusIcon(
                          icon: Icons.assignment_return_outlined,
                          label: 'Returns',
                          onTap: () => _openOrders(context, OrderStatusFilter.returns),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ---- Account actions ----
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Logout'),
                      onTap: () async {
                        await appState.logout();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openOrders(BuildContext context, OrderStatusFilter filter) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MyOrdersScreen(initialFilter: filter)),
    );
  }
}

class _OrderStatusIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OrderStatusIcon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: const Color(AppColors.textDarkValue)),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(AppColors.textDarkValue)),
            ),
          ],
        ),
      ),
    );
  }
}
