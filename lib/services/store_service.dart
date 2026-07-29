import '../models/store.dart';
import 'api_client.dart';

class StoreService {
  final ApiClient _api = ApiClient();

  Future<List<Store>> getStores({bool featuredOnly = false}) async {
    final json = await _api.get('/stores${featuredOnly ? '?featured=true' : ''}');
    return (json as List).map((e) => Store.fromJson(e)).toList();
  }

  /// Stores owned by the currently logged-in seller.
  Future<List<Store>> getMyStores() async {
    final json = await _api.get('/stores/my', auth: true);
    return (json as List).map((e) => Store.fromJson(e)).toList();
  }

  Future<Store> getStore(int id) async {
    final json = await _api.get('/stores/$id');
    return Store.fromJson(json);
  }

  Future<Store> createStore({
    required String storeName,
    String? description,
    String? province,
    String? phone,
  }) async {
    final json = await _api.post('/stores', {
      'storeName': storeName,
      if (description != null) 'description': description,
      if (province != null) 'province': province,
      if (phone != null) 'phone': phone,
    }, auth: true);
    return Store.fromJson(json);
  }

  /// Edits an existing store's profile fields (only non-null ones are sent).
  Future<Store> updateStore(
    int storeId, {
    String? storeName,
    String? description,
    String? province,
    String? phone,
    String? whatsapp,
  }) async {
    final json = await _api.patch('/stores/$storeId', {
      if (storeName != null) 'storeName': storeName,
      if (description != null) 'description': description,
      if (province != null) 'province': province,
      if (phone != null) 'phone': phone,
      if (whatsapp != null) 'whatsapp': whatsapp,
    }, auth: true);
    return Store.fromJson(json);
  }

  Future<void> approveApplication(int applicationId) async {
    await _api.patch('/stores/applications/$applicationId/approve', {}, auth: true);
  }

  Future<void> rejectApplication(int applicationId, {String? notes}) async {
    await _api.patch('/stores/applications/$applicationId/reject', {
      if (notes != null) 'notes': notes,
    }, auth: true);
  }
}
