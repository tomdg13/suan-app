import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../state/app_state.dart';
import '../../services/upload_service.dart';
import 'my_orders_screen.dart';
import 'address_list_screen.dart';

class BuyerProfileScreen extends StatefulWidget {
  const BuyerProfileScreen({super.key});

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  final _uploadService = UploadService();
  final _picker = ImagePicker();
  bool _uploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final avatarUrl = await _uploadService.uploadMyAvatar(Uint8List.fromList(bytes));
      if (mounted) {
        context.read<AppState>().updateAvatarUrl(avatarUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ອັບໂຫລດຮູບບໍ່ສຳເລັດ: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;
    final avatarUrl = user?.avatarUrl;

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
                    GestureDetector(
                      onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(AppColors.primaryValue).withValues(alpha: 0.12),
                            backgroundImage: avatarUrl != null
                                ? NetworkImage('${ApiConfig.mediaBaseUrl}$avatarUrl')
                                : null,
                            child: avatarUrl == null
                                ? const Icon(Icons.person, size: 32, color: Color(AppColors.primaryValue))
                                : null,
                          ),
                          if (_uploadingAvatar)
                            const Positioned.fill(
                              child: CircleAvatar(
                                backgroundColor: Colors.black38,
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                              ),
                            )
                          else
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(AppColors.primaryValue),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
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
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('ທີ່ຢູ່ຂອງຂ້ອຍ'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddressListScreen()),
                      ),
                    ),
                    const Divider(height: 1),
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
