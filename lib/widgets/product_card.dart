import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.decimalPattern('en_US');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: product.imageUrls.isNotEmpty
                      ? Image.network(
                          '${ApiConfig.mediaBaseUrl}${product.imageUrls.first}',
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: const Color(AppColors.primaryValue).withValues(alpha: 0.08),
                          child: const Icon(Icons.image, size: 40, color: Color(AppColors.primaryValue)),
                        ),
                ),
                if (product.isFlashSale)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: const BoxDecoration(
                        color: Color(AppColors.errorValue),
                        borderRadius: BorderRadius.only(bottomRight: Radius.circular(8)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 12, color: Colors.white),
                          SizedBox(width: 2),
                          Text('ດ່ວນ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                if (!product.isActive)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: const Text('ຫມົດ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nameLao,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.25, color: Color(AppColors.textDarkValue)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${priceFormat.format(product.basePrice)} ກີບ',
                    style: const TextStyle(
                      color: Color(AppColors.errorValue),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (product.ratingCount > 0) ...[
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        Text(' ${product.ratingAvg}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        Text('  •  ', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                      ],
                      Text('ຂາຍແລ້ວ ${product.soldCount}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
