import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../../config/constants.dart';
import '../../models/user_address.dart';
import '../../services/address_service.dart';
import '../../services/orders_service.dart';
import '../../services/payment_qr_service.dart';
import '../../services/logistics_provider_service.dart';
import 'location_picker_screen.dart';
import 'payment_proof_screen.dart';


// ---------------------------------------------------------------------
// BuyerPaymentScreen
//
// Flow:
//  1. Load the buyer's saved addresses. If none exist, show a quick
//     inline form to add the first one (also sets it as default).
//  2. Load the admin's currently active payment QR (LAPNet / LAO QR Pay)
//     and show it alongside the order total.
//  3. Buyer scans the QR in their own banking app and pays externally.
//  4. Buyer taps "ຂ້ອຍຈ່າຍແລ້ວ" -> calls POST /orders/checkout with
//     paymentMethod: qr_pay. This creates the order (status: pending,
//     paymentStatus: unpaid) from their current cart. There is no
//     automatic payment verification on the backend yet — an admin
//     confirms payment manually and updates order status.
// ---------------------------------------------------------------------

class BuyerPaymentScreen extends StatefulWidget {
  final double amount;
  final List<({String name, String? imageUrl, double price, double qty})> items;
  final List<({String name, double amount})> feeLines;
  final int? existingOrderId;

  const BuyerPaymentScreen({
    super.key,
    required this.amount,
    this.items = const [],
    this.feeLines = const [],
    this.existingOrderId,
  });

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

  final _logisticsService = LogisticsProviderService();
  List<LogisticsProvider> _deliveryOptions = [];
  int? _selectedDeliveryOptionId;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _lineCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  bool _savingAddress = false;
  bool _locating = false;
  double? _pickedLatitude;
  double? _pickedLongitude;

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
      if (widget.existingOrderId != null) {
        final qrUrl = await _qrService.fetchCurrentQr();
        if (!mounted) return;
        setState(() {
          _qrImageUrl = qrUrl;
          _loading = false;
        });
        return;
      }

      final results = await Future.wait([
        _addressService.findMine(),
        _qrService.fetchCurrentQr(),
        _logisticsService.fetchActive(),
      ]);
      final addresses = results[0] as List<UserAddress>;
      final qrUrl = results[1] as String?;
      final providers = results[2] as List<LogisticsProvider>;

      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _selectedAddressId = addresses.isNotEmpty
            ? addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first).id
            : null;
        _showAddAddressForm = addresses.isEmpty;
        _qrImageUrl = qrUrl;
        _deliveryOptions = providers;
        _selectedDeliveryOptionId = providers.isNotEmpty ? providers.first.id : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'ໂຫຼດຂໍ້ມູນບໍ່ສຳເລັດ: $e';
        _loading = false;
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('ການບໍລິການ GPS ປິດຢູ່. ກະລຸນາເປີດໃຊ້ງານກ່ອນ.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('ການອະນຸຍາດໃຊ້ຕຳແໜ່ງຖືກປະຕິເສດ.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('ການອະນຸຍາດໃຊ້ຕຳແໜ່ງຖືກປະຕິເສດຖາວອນ. ກະລຸນາເປີດໃຊ້ງານໃນການຕັ້ງຄ່າອຸປະກອນ.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() => _locating = false);

      final confirmed = await Navigator.of(context).push<latlong.LatLng>(
        MaterialPageRoute(
          builder: (_) => LocationPickerScreen(
            initialCenter: latlong.LatLng(position.latitude, position.longitude),
          ),
        ),
      );
      if (confirmed == null || !mounted) return;

      try {
        final geocoding = Geocoding();
        final placemarks = await geocoding.placemarkFromCoordinates(
          confirmed.latitude,
          confirmed.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          if (!mounted) return;
          setState(() {
            _lineCtrl.text = [place.street, place.subLocality]
                .where((p) => p != null && p.isNotEmpty)
                .join(', ');
            _villageCtrl.text = place.subLocality ?? '';
            _districtCtrl.text = place.locality ?? '';
            _provinceCtrl.text = place.administrativeArea ?? '';
          });
        }
      } catch (_) {
        // ບໍ່ຮ້າຍແຮງ — reverse geocoding ອາດບໍ່ມີໃນທຸກ platform
      }

      if (!mounted) return;
      setState(() {
        _pickedLatitude = confirmed.latitude;
        _pickedLongitude = confirmed.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ບັນທຶກຕຳແໜ່ງສຳເລັດ')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _locating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ບໍ່ສາມາດດຶງຕຳແໜ່ງໄດ້: $e')),
      );
    }
  }

  Future<void> _saveAddress() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _lineCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ກະລຸນາປ້ອນຊື່, ເບີໂທ ແລະ ທີ່ຢູ່')),
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
        latitude: _pickedLatitude,
        longitude: _pickedLongitude,
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
        SnackBar(content: Text('ບໍ່ສາມາດບັນທຶກທີ່ຢູ່ໄດ້: $e')),
      );
    }
  }

  Future<void> _confirmPaid() async {
    if (widget.existingOrderId != null) {
      setState(() => _confirming = true);
      if (!mounted) return;
      setState(() => _confirming = false);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PaymentProofScreen(orderIds: [widget.existingOrderId!])),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }

    if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ກະລຸນາເພີ່ມ ຫຼື ເລືອກທີ່ຢູ່ຈັດສົ່ງກ່ອນ')),
      );
      return;
    }
    setState(() => _confirming = true);
    try {
      final selectedProvider = _deliveryOptions.firstWhere(
        (p) => p.id == _selectedDeliveryOptionId,
        orElse: () => _deliveryOptions.first,
      );
      final isPickup = selectedProvider.type == 'store_pickup';
      final result = await _ordersService.checkout(
        addressId: _selectedAddressId!,
        paymentMethod: PaymentMethod.qrPay,
        deliveryMethod: isPickup ? DeliveryMethod.pickup : DeliveryMethod.delivery,
        courierName: isPickup ? null : selectedProvider.name,
      );
      if (!mounted) return;
      setState(() => _confirming = false);

      final orders = result is List ? result : [result];
      if (orders.isEmpty) {
        Navigator.of(context).pop(result);
        return;
      }
      final orderIds = orders
          .map((o) => (o as Map<String, dynamic>)['id'] as int?)
          .whereType<int>()
          .toList();

      if (orderIds.isEmpty) {
        Navigator.of(context).pop(result);
        return;
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PaymentProofScreen(orderIds: orderIds)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ບໍ່ສາມາດສ້າງອໍເດີໄດ້: $e')),
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
          'ຈ່າຍດ້ວຍ QR',
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
                        if (widget.existingOrderId == null) ...[
                          _buildAddressSection(),
                          const SizedBox(height: 16),
                          _buildDeliveryMethodSection(),
                          const SizedBox(height: 16),
                        ],
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
            OutlinedButton(onPressed: _load, child: const Text('ລອງໃໝ່')),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    final priceFormat = NumberFormat.decimalPattern('en_US');

    String qtyLabel(double qty) => qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();

    Widget lineRow({required Widget left, required String rightText, TextStyle? rightStyle}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 8),
            Text(
              rightText,
              style: rightStyle ??
                  const TextStyle(fontSize: 13, color: Color(AppColors.textDarkValue), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(AppColors.backgroundValue),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ລາຍລະອຽດການຊຳລະ', style: TextStyle(color: Colors.black54, fontSize: 13)),
          if (widget.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...widget.items.map((item) {
              final subtotal = item.price * item.qty;
              return lineRow(
                left: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(AppColors.borderValue)),
                        color: Colors.white,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: item.imageUrl != null
                          ? Image.network(
                              '${ApiConfig.mediaBaseUrl}${item.imageUrl}',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 14, color: Colors.black26),
                            )
                          : const Icon(Icons.image, size: 14, color: Colors.black26),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.name}  ${priceFormat.format(item.price)} x ${qtyLabel(item.qty)}',
                        style: const TextStyle(fontSize: 13, color: Color(AppColors.textDarkValue)),
                      ),
                    ),
                  ],
                ),
                rightText: '${priceFormat.format(subtotal)} ກີບ',
              );
            }),
          ],
          if (widget.feeLines.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(height: 1, color: const Color(AppColors.borderValue)),
            const SizedBox(height: 6),
            ...widget.feeLines.map(
              (fee) => lineRow(
                left: Text(fee.name, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                rightText: '${priceFormat.format(fee.amount)} ກີບ',
                rightStyle: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Container(height: 1, color: const Color(AppColors.borderValue)),
          const SizedBox(height: 10),
          lineRow(
            left: const Text('ລວມທັງໝົດ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            rightText: '${priceFormat.format(widget.amount)} ກີບ',
            rightStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(AppColors.primaryValue)),
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
            const Text('ທີ່ຢູ່ຈັດສົ່ງ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 10),

            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(AppColors.primaryValue),
                  side: const BorderSide(color: Color(AppColors.primaryValue)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 16),
                label: Text(_locating ? 'ກຳລັງດຶງຕຳແໜ່ງ...' : 'ປັກໝຸດຕຳແໜ່ງໃນແຜນທີ່'),
              ),
            ),
            if (_pickedLatitude != null) ...[
              const SizedBox(height: 6),
              Text(
                'ຕຳແໜ່ງ: ${_pickedLatitude!.toStringAsFixed(5)}, ${_pickedLongitude!.toStringAsFixed(5)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 10),

            _addressField(_nameCtrl, 'ຊື່ຜູ້ຮັບ'),
            const SizedBox(height: 8),
            _addressField(_phoneCtrl, 'ເບີໂທ', keyboardType: TextInputType.phone),
            const SizedBox(height: 8),
            _addressField(_lineCtrl, 'ທີ່ຢູ່ (ຖະໜົນ, ເລກທີ່ເຮືອນ)'),
            const SizedBox(height: 8),
            _addressField(_villageCtrl, 'ບ້ານ (ບໍ່ບັງຄັບ)'),
            const SizedBox(height: 8),
            _addressField(_districtCtrl, 'ເມືອງ (ບໍ່ບັງຄັບ)'),
            const SizedBox(height: 8),
            _addressField(_provinceCtrl, 'ແຂວງ (ບໍ່ບັງຄັບ)'),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryValue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _savingAddress ? null : _saveAddress,
                child: Text(_savingAddress ? 'ກຳລັງບັນທຶກ...' : 'ບັນທຶກທີ່ຢູ່'),
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
              const Text('ສົ່ງໃຫ້', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _showAddAddressForm = true;
                  _pickedLatitude = null;
                  _pickedLongitude = null;
                  _nameCtrl.clear();
                  _phoneCtrl.clear();
                  _lineCtrl.clear();
                  _villageCtrl.clear();
                  _districtCtrl.clear();
                  _provinceCtrl.clear();
                }),
                child: const Text('+ ເພີ່ມທີ່ຢູ່ໃໝ່'),
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

  Widget _buildDeliveryMethodSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(AppColors.borderValue)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ວິທີການຈັດສົ່ງ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          if (_deliveryOptions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('ບໍ່ມີວິທີການຈັດສົ່ງໃຫ້ເລືອກ', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ..._deliveryOptions.map((option) => RadioListTile<int>(
                value: option.id,
                groupValue: _selectedDeliveryOptionId,
                onChanged: (v) => setState(() => _selectedDeliveryOptionId = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(AppColors.primaryValue),
                controlAffinity: ListTileControlAffinity.trailing,
                secondary: (option.logoUrl != null && option.logoUrl!.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          '${ApiConfig.mediaBaseUrl}${option.logoUrl}',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.local_shipping, color: Colors.grey),
                        ),
                      )
                    : const Icon(Icons.local_shipping_outlined, color: Colors.grey),
                title: Text(
                  option.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: option.description != null
                    ? Text(option.description!, style: const TextStyle(fontSize: 12))
                    : null,
              )),
        ],
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
          const Text('ສະແກນເພື່ອຈ່າຍ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                        'ຍັງບໍ່ມີ QR ການຊຳລະ.\nກະລຸນາຕິດຕໍ່ທີມງານ.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            'ເປີດແອັບທະນາຄານ, ສະແກນ QR ນີ້ ແລະ ຈ່າຍຕາມຍອດຂ້າງເທິງ.',
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
          _confirming
              ? (widget.existingOrderId != null ? 'ກຳລັງໂຫຼດ...' : 'ກຳລັງສ້າງອໍເດີ...')
              : 'ຂ້ອຍຈ່າຍແລ້ວ',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
