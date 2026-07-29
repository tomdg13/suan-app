import 'api_client.dart';

class DashboardService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> getOverview() async {
    final json = await _api.get('/dashboard/overview', auth: true);
    return json as Map<String, dynamic>;
  }

  Future<List<dynamic>> getPendingApplications() async {
    final json = await _api.get('/dashboard/pending-applications', auth: true);
    return json as List<dynamic>;
  }

  Future<List<dynamic>> getPendingWithdrawals() async {
    final json = await _api.get('/dashboard/pending-withdrawals', auth: true);
    return json as List<dynamic>;
  }

  Future<List<dynamic>> getTopStores() async {
    final json = await _api.get('/dashboard/top-stores', auth: true);
    return json as List<dynamic>;
  }

  Future<List<dynamic>> getLowStock() async {
    final json = await _api.get('/dashboard/low-stock', auth: true);
    return json as List<dynamic>;
  }
}
