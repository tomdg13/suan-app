import '../services/api_client.dart';

class LogisticsProvider {
  final int id;
  final String name;
  final String? description;
  final String type; // logistic | customer_courier | store_pickup
  final String? logoUrl;
  final bool isActive;
  final int sortOrder;

  LogisticsProvider({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    this.logoUrl,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory LogisticsProvider.fromJson(Map<String, dynamic> j) => LogisticsProvider(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        type: j['type'] as String? ?? 'logistic',
        logoUrl: j['logo_url'] as String?,
        isActive: j['is_active'] == 1 || j['is_active'] == true,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'type': type,
        'logo_url': logoUrl,
        'is_active': isActive,
        'sort_order': sortOrder,
      };
}

class LogisticsProviderService {
  final ApiClient _api = ApiClient();

  Future<List<LogisticsProvider>> fetchActive() async {
    final data = await _api.get('/logistics-provider?active=1');
    return (data as List).map((e) => LogisticsProvider.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<LogisticsProvider>> fetchAll() async {
    final data = await _api.get('/logistics-provider');
    return (data as List).map((e) => LogisticsProvider.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LogisticsProvider> create(LogisticsProvider provider) async {
    final data = await _api.post('/logistics-provider', provider.toJson(), auth: true);
    return LogisticsProvider.fromJson(data as Map<String, dynamic>);
  }

  Future<LogisticsProvider> update(int id, LogisticsProvider provider) async {
    final data = await _api.put('/logistics-provider/$id', provider.toJson(), auth: true);
    return LogisticsProvider.fromJson(data as Map<String, dynamic>);
  }

  /// PATCH /logistics-provider/reorder — persists new sort_order values
  /// after a drag-and-drop reorder in the admin UI.
  Future<void> reorderProviders(List<int> orderedIds) async {
    final items = [
      for (var i = 0; i < orderedIds.length; i++)
        {'id': orderedIds[i], 'sortOrder': i + 1},
    ];
    await _api.patch('/logistics-provider/reorder', {'items': items}, auth: true);
  }

  Future<void> toggleActive(int id) async {
    await _api.patch('/logistics-provider/$id/toggle-active', {}, auth: true);
  }

  Future<void> delete(int id) async {
    await _api.delete('/logistics-provider/$id', auth: true);
  }
}
