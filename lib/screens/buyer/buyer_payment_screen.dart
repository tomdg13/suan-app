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
//  4. Buyer taps "I've Paid" -> calls POST /orders/checkout with
//     paymentMethod: qr_pay. This creates the order (status: pending,
//     paymentStatus: unpaid) from their current cart. There is no
//     automatic payment verification on the backend yet — an admin
//     confirms payment manually and updates order status.
// ---------------------------------------------------------------------

class BuyerPaymentScreen extends StatefulWidget {
  final double amount;
  // When set, this screen pays for an ALREADY-CREATED order (e.g. the
  // buyer tapped "Pay Now" on an existing unpaid order from My Orders)
  // instead of creating a new one from the cart. Address/delivery-method
  // selection is skipped since those were already set at checkout time.
  final int? existingOrderId;

  const BuyerPaymentScreen({super.key, required this.amount, this.existingOrderId});

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

  // Delivery choice. "Anousith Logistic" and "Standard Delivery" are both
  // DeliveryMethod.delivery under the hood, just with a different courier
  // name attached — "Store Pickup" is DeliveryMethod.pickup, no courier.
  static const _deliveryOptions = <String>['Anousith Logistic', 'Standard Delivery', 'Store Pickup'];
  String _selectedDeliveryOption = _deliveryOptions.first;

  // Quick add-address form controllers.
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
        // Paying an existing order — only need the QR, no address/cart work.
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

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      // 1. Make sure location services + permission are actually available.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are turned off. Please enable GPS.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied. Enable it in device settings.');
      }

      // 2. Get the current GPS position, to use as the map's starting point.
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() => _locating = false);

      // 3. Open the map so the buyer can fine-tune the exact pin — GPS
      //    accuracy alone (especially indoors/on web) is often off by
      //    tens of meters, so let them drag to the real front door.
      final confirmed = await Navigator.of(context).push<latlong.LatLng>(
        MaterialPageRoute(
          builder: (_) => LocationPickerScreen(
            initialCenter: latlong.LatLng(position.latitude, position.longitude),
          ),
        ),
      );
      if (confirmed == null || !mounted) return; // buyer backed out of the map

      // 4. Reverse-geocode the CONFIRMED pin (not the raw GPS point) to
      //    fill in village/district/province/address automatically. If
      //    this fails (e.g. web platform limitations, or the point is
      //    somewhere with no address data), we still keep the
      //    coordinates — the buyer can type the address fields by hand.
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
        // Non-fatal — reverse geocoding isn't available on every platform
        // (e.g. Flutter Web needs extra setup). Coordinates are still saved.
      }

      if (!mounted) return;
      setState(() {
        _pickedLatitude = confirmed.latitude;
        _pickedLongitude = confirmed.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location captured')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _locating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
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
        SnackBar(content: Text('Could not save address: $e')),
      );
    }
  }

  Future<void> _confirmPaid() async {
    // Paying an EXISTING order — skip checkout entirely, go straight to
    // uploading proof for that order.
    if (widget.existingOrderId != null) {
      setState(() => _confirming = true);
      if (!mounted) return;
      setState(() => _confirming = false);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PaymentProofScreen(orderId: widget.existingOrderId!)),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }

    if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add or select a delivery address first')),
      );
      return;
    }
    setState(() => _confirming = true);
    try {
      final isPickup = _selectedDeliveryOption == 'Store Pickup';
      final result = await _ordersService.checkout(
        addressId: _selectedAddressId!,
        paymentMethod: PaymentMethod.qrPay,
        deliveryMethod: isPickup ? DeliveryMethod.pickup : DeliveryMethod.delivery,
        courierName: isPickup ? null : _selectedDeliveryOption,
      );
      if (!mounted) return;
      setState(() => _confirming = false);

      // Backend returns a LIST (one order per store in the cart). Take
      // the first one — if the buyer had items from multiple stores,
      // this only attaches payment proof to the first order; the rest
      // stay pending until confirmed separately.
      final orders = result is List ? result : [result];
      if (orders.isEmpty) {
        Navigator.of(context).pop(result);
        return;
      }
      final firstOrder = orders.first as Map<String, dynamic>;
      final orderId = firstOrder['id'] as int?;

      if (orderId == null) {
        // Shouldn't happen, but don't strand the buyer if it does.
        Navigator.of(context).pop(result);
        return;
      }

      // Send them straight into the payment-proof upload step so the
      // RRN gets captured while it's still fresh in their banking app.
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PaymentProofScreen(orderId: orderId)),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
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

            // GPS button — fills the fields below automatically when
            // possible; coordinates are saved either way.
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
                label: Text(_locating ? 'Getting location...' : 'Pin location on map'),
              ),
            ),
            if (_pickedLatitude != null) ...[
              const SizedBox(height: 6),
              Text(
                'Location: ${_pickedLatitude!.toStringAsFixed(5)}, ${_pickedLongitude!.toStringAsFixed(5)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
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
          const Text('Delivery Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ..._deliveryOptions.map((option) => RadioListTile<String>(
                value: option,
                groupValue: _selectedDeliveryOption,
                onChanged: (v) => setState(() => _selectedDeliveryOption = v!),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(AppColors.primaryValue),
                title: Text(option, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  option == 'Store Pickup'
                      ? 'Collect your order from the store'
                      : option == 'Anousith Logistic'
                          ? 'Delivered by Anousith Logistic courier'
                          : 'Standard delivery to your address',
                  style: const TextStyle(fontSize: 12),
                ),
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
          _confirming ? (widget.existingOrderId != null ? 'Loading...' : 'Placing order...') : "I've Paid",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
