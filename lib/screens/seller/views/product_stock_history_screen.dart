import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/constants.dart';
import '../../../models/product.dart';
import '../../../models/product_stock_log.dart';
import '../../../services/product_service.dart';

/// Timeline of every stock adjustment for one product — who changed it,
/// when, by how much, and what the resulting count was.
class ProductStockHistoryScreen extends StatefulWidget {
  final Product product;

  const ProductStockHistoryScreen({super.key, required this.product});

  @override
  State<ProductStockHistoryScreen> createState() => _ProductStockHistoryScreenState();
}

class _ProductStockHistoryScreenState extends State<ProductStockHistoryScreen> {
  final _productService = ProductService();
  List<ProductStockLogEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _productService.getStockHistory(widget.product.id);
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      backgroundColor: const Color(AppColors.backgroundValue),
      appBar: AppBar(title: Text('${widget.product.nameLao} — ປະຫວັດຄັງສິນຄ້າ')), // Stock history
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _entries.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(child: Text('ບໍ່ມີການປ່ຽນແປງຄັງສິນຄ້າ')), // No stock changes yet
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        final isIncrease = entry.delta > 0;
                        final color = isIncrease ? const Color(AppColors.primaryValue) : const Color(AppColors.errorValue);
                        final sign = isIncrease ? '+' : '';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(AppColors.borderValue)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isIncrease ? Icons.add : Icons.remove,
                                  size: 18,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$sign${entry.delta.toStringAsFixed(0)}',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateFormat.format(entry.createdAt),
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'ຄົງເຫຼືອ ${entry.resultingStock.toStringAsFixed(0)}', // Remaining after
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
