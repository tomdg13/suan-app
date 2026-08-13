import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../../config/constants.dart';
import '../../models/user_address.dart';
import '../../services/address_service.dart';
import 'location_picker_screen.dart';

/// Add or edit a saved address. Pass [existing] to edit; omit to create new.
class AddressFormScreen extends StatefulWidget {
  final UserAddress? existing;
  const AddressFormScreen({super.key, this.existing});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = AddressService();

  late final TextEditingController _labelCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressLineCtrl;
  late final TextEditingController _villageCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _provinceCtrl;
  bool _isDefault = false;
  bool _saving = false;
  bool _locating = false;

  double? _latitude;
  double? _longitude;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl = TextEditingController(text: e?.label ?? 'home');
    _nameCtrl = TextEditingController(text: e?.recipientName ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _addressLineCtrl = TextEditingController(text: e?.addressLine ?? '');
    _villageCtrl = TextEditingController(text: e?.village ?? '');
    _districtCtrl = TextEditingController(text: e?.district ?? '');
    _provinceCtrl = TextEditingController(text: e?.province ?? '');
    _isDefault = e?.isDefault ?? false;
    _latitude = e?.latitude;
    _longitude = e?.longitude;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressLineCtrl.dispose();
    _villageCtrl.dispose();
    _districtCtrl.dispose();
    _provinceCtrl.dispose();
    super.dispose();
  }

  /// Opens the map pin picker. If a pin already exists (editing an address
  /// that has one), starts centered there; otherwise gets a fresh GPS fix
  /// first — same flow as buyer_payment_screen's "use current location".
  Future<void> _pinLocation() async {
    latlong.LatLng initialCenter;

    if (_latitude != null && _longitude != null) {
      initialCenter = latlong.LatLng(_latitude!, _longitude!);
    } else {
      setState(() => _locating = true);
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('ກະລຸນາເປີດ GPS ກ່ອນ');
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('ບໍ່ອະນຸຍາດການເຂົ້າເຖິງຕຳແໜ່ງ');
          }
        }
        if (permission == LocationPermission.deniedForever) {
          throw Exception('ການອະນຸຍາດຖືກປະຕິເສດຖາວອນ, ກະລຸນາເປີດຈາກການຕັ້ງຄ່າອຸປະກອນ');
        }
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        initialCenter = latlong.LatLng(position.latitude, position.longitude);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
        return;
      } finally {
        if (mounted) setState(() => _locating = false);
      }
    }

    if (!mounted) return;
    final confirmed = await Navigator.of(context).push<latlong.LatLng>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialCenter: initialCenter),
      ),
    );
    if (confirmed == null) return;
    setState(() {
      _latitude = confirmed.latitude;
      _longitude = confirmed.longitude;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await _service.update(
          widget.existing!.id,
          label: _labelCtrl.text.trim(),
          recipientName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          addressLine: _addressLineCtrl.text.trim(),
          village: _villageCtrl.text.trim().isEmpty ? null : _villageCtrl.text.trim(),
          district: _districtCtrl.text.trim().isEmpty ? null : _districtCtrl.text.trim(),
          province: _provinceCtrl.text.trim().isEmpty ? null : _provinceCtrl.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          isDefault: _isDefault,
        );
      } else {
        await _service.create(
          label: _labelCtrl.text.trim(),
          recipientName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          addressLine: _addressLineCtrl.text.trim(),
          village: _villageCtrl.text.trim().isEmpty ? null : _villageCtrl.text.trim(),
          district: _districtCtrl.text.trim().isEmpty ? null : _districtCtrl.text.trim(),
          province: _provinceCtrl.text.trim().isEmpty ? null : _provinceCtrl.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          isDefault: _isDefault,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPin = _latitude != null && _longitude != null;

    return Scaffold(
      backgroundColor: const Color(AppColors.backgroundValue),
      appBar: AppBar(
        title: Text(_isEditing ? 'ແກ້ໄຂທີ່ຢູ່' : 'ເພີ່ມທີ່ຢູ່'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_labelCtrl, 'ປ້າຍຊື່ (ບ້ານ / ບ່ອນເຮັດວຽກ)'),
            _field(_nameCtrl, 'ຊື່ຜູ້ຮັບ', required: true),
            _field(_phoneCtrl, 'ເບີໂທ', required: true, keyboardType: TextInputType.phone),
            _field(_addressLineCtrl, 'ທີ່ຢູ່ (ບ້ານເລກທີ, ຖະໜົນ)', required: true),
            _field(_villageCtrl, 'ບ້ານ'),
            _field(_districtCtrl, 'ເມືອງ'),
            _field(_provinceCtrl, 'ແຂວງ'),

            // ---- Pin location ----
            InkWell(
              onTap: _locating ? null : _pinLocation,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasPin ? const Color(AppColors.primaryValue) : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: hasPin ? const Color(AppColors.primaryValue) : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hasPin
                            ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                            : 'ປັກໝຸດຕຳແໜ່ງຈັດສົ່ງ',
                        style: TextStyle(
                          fontSize: 14,
                          color: hasPin ? Colors.black87 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    if (_locating)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Text(
                        hasPin ? 'ແກ້ໄຂ' : 'ປັກໝຸດ',
                        style: const TextStyle(color: Color(AppColors.primaryValue), fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ຕັ້ງເປັນທີ່ຢູ່ຄ່າເລີ່ມຕົ້ນ'),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              activeColor: const Color(AppColors.primaryValue),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryValue),
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'ບັນທຶກ' : 'ເພີ່ມທີ່ຢູ່'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool required = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'ກະລຸນາປ້ອນ' : null : null,
      ),
    );
  }
}
