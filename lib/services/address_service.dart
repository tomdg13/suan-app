import '../models/user_address.dart';
import 'api_client.dart';

/// Manages the logged-in buyer's own saved addresses.
/// Matches suan-api's UserAddressesModule: /user-addresses/*
class AddressService {
  final ApiClient _api = ApiClient();

  Future<List<UserAddress>> findMine() async {
    final json = await _api.get('/user-addresses/my', auth: true);
    final list = json as List<dynamic>;
    return list.map((e) => UserAddress.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UserAddress> create({
    String? label,
    required String recipientName,
    required String phone,
    required String addressLine,
    String? village,
    String? district,
    String? province,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final json = await _api.post(
      '/user-addresses',
      {
        if (label != null) 'label': label,
        'recipientName': recipientName,
        'phone': phone,
        'addressLine': addressLine,
        if (village != null) 'village': village,
        if (district != null) 'district': district,
        if (province != null) 'province': province,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'isDefault': isDefault ? 1 : 0,
      },
      auth: true,
    );
    return UserAddress.fromJson(json);
  }

  Future<UserAddress> update(
    int id, {
    String? label,
    String? recipientName,
    String? phone,
    String? addressLine,
    String? village,
    String? district,
    String? province,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) async {
    final json = await _api.patch(
      '/user-addresses/$id',
      {
        if (label != null) 'label': label,
        if (recipientName != null) 'recipientName': recipientName,
        if (phone != null) 'phone': phone,
        if (addressLine != null) 'addressLine': addressLine,
        if (village != null) 'village': village,
        if (district != null) 'district': district,
        if (province != null) 'province': province,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (isDefault != null) 'isDefault': isDefault ? 1 : 0,
      },
      auth: true,
    );
    return UserAddress.fromJson(json);
  }

  /// Convenience call for the "set as default" tap in the address list.
  Future<UserAddress> setDefault(int id) => update(id, isDefault: true);

  Future<void> remove(int id) async {
    await _api.delete('/user-addresses/$id', auth: true);
  }
}
