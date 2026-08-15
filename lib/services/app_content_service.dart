import 'api_client.dart';

class AppContentService {
  final ApiClient _api = ApiClient();

  /// Fetches all app_content rows as a { key: value } map.
  Future<Map<String, String>> fetchAll() async {
    final rows = await _api.get('/app-content') as List<dynamic>;
    return {for (final row in rows) row['key'] as String: row['value'] as String};
  }

  /// Fetches a single key's value. Returns null if not found or on error.
  Future<String?> fetchOne(String key) async {
    try {
      final data = await _api.get('/app-content/$key');
      if (data == null) return null;
      return data['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Updates a key's value. Requires the caller to be logged in as admin
  /// (ApiClient attaches the saved JWT automatically when auth: true).
  Future<void> update(String key, String value) async {
    await _api.patch('/app-content/$key', {'value': value}, auth: true);
  }
}
