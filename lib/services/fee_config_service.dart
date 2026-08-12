import 'api_client.dart';

enum FeeType { flat, percent }

FeeType _feeTypeFromString(String? s) => s == 'percent' ? FeeType.percent : FeeType.flat;

String feeTypeToString(FeeType t) => t == FeeType.percent ? 'percent' : 'flat';

class FeeConfig {
  final int id;
  final String name;
  final FeeType type;
  final double value;
  final int sortOrder;
  final bool isActive;

  FeeConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    required this.sortOrder,
    required this.isActive,
  });

  factory FeeConfig.fromJson(Map<String, dynamic> json) => FeeConfig(
        id: json['id'] as int,
        name: json['name'] ?? '',
        type: _feeTypeFromString(json['type']),
        value: double.tryParse('${json['value']}') ?? 0,
        sortOrder: json['sortOrder'] is int ? json['sortOrder'] as int : int.tryParse('${json['sortOrder']}') ?? 0,
        isActive: (json['isActive'] == 1 || json['isActive'] == true),
      );
}

class FeeLine {
  final String name;
  final FeeType type;
  final double value;
  final double amount;

  FeeLine({required this.name, required this.type, required this.value, required this.amount});

  factory FeeLine.fromJson(Map<String, dynamic> json) => FeeLine(
        name: json['name'] ?? '',
        type: _feeTypeFromString(json['type']),
        value: double.tryParse('${json['value']}') ?? 0,
        amount: double.tryParse('${json['amount']}') ?? 0,
      );
}

class FeeConfigService {
  FeeConfigService();

  final ApiClient _api = ApiClient();

  Future<List<FeeConfig>> fetchActive() async {
    final body = await _api.get('/fees/active');
    return (body as List).map((e) => FeeConfig.fromJson(e as Map<String, dynamic>)).toList();
  }

  List<FeeLine> computeFeeLines(List<FeeConfig> configs, double subtotal) {
    return configs.map((c) {
      final amount = c.type == FeeType.percent ? (subtotal * c.value / 100).roundToDouble() : c.value.roundToDouble();
      return FeeLine(name: c.name, type: c.type, value: c.value, amount: amount);
    }).toList();
  }

  double sumFeeLines(List<FeeLine> lines) => lines.fold(0, (sum, l) => sum + l.amount);

  Future<List<FeeConfig>> fetchAll() async {
    final body = await _api.get('/fees', auth: true);
    return (body as List).map((e) => FeeConfig.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<FeeConfig> create({
    required String name,
    required FeeType type,
    required double value,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final body = await _api.post(
      '/fees',
      {
        'name': name,
        'type': feeTypeToString(type),
        'value': value,
        'sortOrder': sortOrder,
        'isActive': isActive ? 1 : 0,
      },
      auth: true,
    );
    return FeeConfig.fromJson(body as Map<String, dynamic>);
  }

  Future<FeeConfig> update(
    int id, {
    String? name,
    FeeType? type,
    double? value,
    int? sortOrder,
    bool? isActive,
  }) async {
    final patch = <String, dynamic>{
      if (name != null) 'name': name,
      if (type != null) 'type': feeTypeToString(type),
      if (value != null) 'value': value,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (isActive != null) 'isActive': isActive ? 1 : 0,
    };
    final body = await _api.patch('/fees/$id', patch, auth: true);
    return FeeConfig.fromJson(body as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.delete('/fees/$id', auth: true);
  }
}
