import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../models/user_address.dart';
import '../../services/address_service.dart';
import '../../services/orders_service.dart';
import '../../services/payment_qr_service.dart';

// ---------------------------------------------------------------------
// BuyerPaymentScreen
//
// Flow:
//  1. Load the buyer's saved addresses. If none exist, show a quick
//     inline form to add the first one (also sets it as default).
//  2. Load the admin's currently active payment QR (LAPNet / LAO QR Pay)
//     and show it alongside the order total.
//  3. Buyer scans the QR in their own banking app and pays externally.
//  4. Buyer taps "I've Paid" -> calls POST /orders/checkout with
//     paymentMethod: qr_pay. This creates the order (status: pending,
//     paymentStatus: unpaid) from their current cart. There is no
//     automatic payment verification on the backend yet — an admin
//     confirms payment manually and updates order status.
// ---------------------------------------------------------------------

class BuyerPaymentScreen extends StatefulWidget {
  final double amount;

  const BuyerPaymentScreen({super.key, required this.amount});

  @override
  State<BuyerPaymentScreen> createState() => _BuyerPaymentScreenState();
}

class _BuyerPaymentScreenState extends State<BuyerPaymentScreen> {
  final _addressService = AddressService();
  final _qrService = PaymentQrService();
  final _ordersService = OrdersService();

  bool _loading = true;
  String? _loadError;

  List<UserAddress> _addresses = [];
  int? _selectedAddressId;
  bool _showAddAddressForm = false;

  String? _qrImageUrl;
  bool _confirming = false;

  // Quick add-address form controllers.
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _lineCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  bool _savingAddress = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _lineCtrl.dispose();
    _villageCtrl.dispose();
    _districtCtrl.dispose();
    _provinceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _addressService.findMine(),
        _qrService.fetchCurrentQr(),
      ]);
      final addresses = results[0] as List<UserAddress>;
      final qrUrl = results[1] as String?;

      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _selectedAddressId = addresses.isNotEmpty
            ? addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first).id
            : null;
        _showAddAddressForm = addresses.isEmpty;
        _qrImageUrl = qrUrl;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Failed to load: $e';
        _loading = false;
      });
    }
  }

  Future<void> _saveAddress() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _lineCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, phone, and address are required')),
      );
      return;
    }
    setState(() => _savingAddress = true);
    try {
      final address = await _addressService.create(
        recipientName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        addressLine: _lineCtrl.text.trim(),
        village: _villageCtrl.text.trim().isEmpty ? null : _villageCtrl.text.trim(),
        district: _districtCtrl.text.trim().isEmpty ? null : _districtCtrl.text.trim(),
        province: _provinceCtrl.text.trim().isEmpty ? null : _provinceCtrl.text.trim(),
        isDefault: true,
      );
      if (!mounted) return;
      setState(() {
        _addresses = [address, ..._addresses];
        _selectedAddressId = address.id;
        _showAddAddressForm = false;
        _savingAddress = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingAddress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save address: $e')),
      );
    }
  }

  Future<void> _confirmPaid() async {
    if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add or select a delivery address first')),
      );
      return;
    }
    setState(() => _confirming = true);
    try {
      final order = await _ordersService.checkout(
        addressId: _selectedAddressId!,
        paymentMethod: PaymentMethod.qrPay,
      );
      if (!mounted) return;
      setState(() => _confirming = false);
      // Order created with status pending / paymentStatus unpaid — an
      // admin confirms payment manually. Pop back with the order so the
      // caller can show an order-confirmation screen.
      Navigator.of(context).pop(order);
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Pay with QR',
          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(AppColors.primaryValue)))
            : _loadError != null
                ? _buildErrorView()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAmountCard(),
                        const SizedBox(height: 16),
                        _buildAddressSection(),
                        const SizedBox(height: 16),
                        _buildQrSection(),
                        const SizedBox(height: 20),
                        _buildConfirmButton(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    final priceFormat = NumberFormat.decimalPattern('en_US');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(AppColors.backgroundValue),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Text('Amount to Pay', style: TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            '${priceFormat.format(widget.amount)} ກີບ',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(AppColors.primaryValue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    if (_showAddAddressForm) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(AppColors.borderValue)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 10),
            _addressField(_nameCtrl, 'Recipient name'),
            const SizedBox(height: 8),
            _addressField(_phoneCtrl, 'Phone', keyboardType: TextInputType.phone),
            const SizedBox(height: 8),
            _addressField(_lineCtrl, 'Address (street, house no.)'),
            const SizedBox(height: 8),
            _addressField(_villageCtrl, 'Village (optional)'),
            const SizedBox(height: 8),
            _addressField(_districtCtrl, 'District (optional)'),
            const SizedBox(height: 8),
            _addressField(_provinceCtrl, 'Province (optional)'),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryValue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _savingAddress ? null : _saveAddress,
                child: Text(_savingAddress ? 'Saving...' : 'Save Address'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(AppColors.borderValue)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Deliver to', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _showAddAddressForm = true),
                child: const Text('+ Add new'),
              ),
            ],
          ),
          ..._addresses.map((a) => RadioListTile<int>(
                value: a.id,
                groupValue: _selectedAddressId,
                onChanged: (v) => setState(() => _selectedAddressId = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(AppColors.primaryValue),
                title: Text('${a.recipientName} · ${a.phone}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(a.shortDisplay, style: const TextStyle(fontSize: 12)),
              )),
        ],
      ),
    );
  }

  Widget _addressField(TextEditingController controller, String label, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildQrSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(AppColors.borderValue)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Text('Scan to Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.grey.shade50,
            ),
            clipBehavior: Clip.antiAlias,
            child: _qrImageUrl != null
                ? Image.network(_qrImageUrl!, fit: BoxFit.contain)
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No payment QR has been set up yet.\nPlease contact support.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            'Open your banking app, scan this QR, and pay the amount above.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(AppColors.primaryValue),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: (_confirming || _qrImageUrl == null) ? null : _confirmPaid,
        child: Text(
          _confirming ? 'Placing order...' : "I've Paid",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
