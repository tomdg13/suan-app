import '../models/review.dart';
import 'api_client.dart';

class ReviewService {
  final ApiClient _api = ApiClient();

  Future<List<Review>> getStoreReviews(int storeId) async {
    final json = await _api.get('/reviews/store/$storeId');
    return (json as List).map((e) => Review.fromJson(e)).toList();
  }
}
