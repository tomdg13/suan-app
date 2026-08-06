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
        'isDefault': isDefault ? 1 : 0,
      },
      auth: true,
    );
    return UserAddress.fromJson(json);
  }
}
