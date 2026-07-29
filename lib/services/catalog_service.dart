import '../models/category.dart';
import '../models/unit.dart';
import 'api_client.dart';

class CatalogService {
  final ApiClient _api = ApiClient();

  Future<List<ProductCategory>> getCategories() async {
    final json = await _api.get('/categories');
    return (json as List).map((e) => ProductCategory.fromJson(e)).toList();
  }

  Future<List<ProductUnit>> getUnits() async {
    final json = await _api.get('/units');
    return (json as List).map((e) => ProductUnit.fromJson(e)).toList();
  }
}
