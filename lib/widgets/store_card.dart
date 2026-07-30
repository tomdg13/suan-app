import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/store.dart';

class StoreCard extends StatelessWidget {
  final Store store;
  final VoidCallback onTap;

  const StoreCard({super.key, required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final coverUrl = store.coverUrl != null ? '${ApiConfig.mediaBaseUrl}${store.coverUrl}' : null;
    final logoUrl = store.logoUrl != null ? '${ApiConfig.mediaBaseUrl}${store.logoUrl}' : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 70,
              width: double.infinity,
              child: coverUrl != null
                  ? Image.network(coverUrl, fit: BoxFit.cover)
                  : Container(color: const Color(AppColors.primaryValue).withValues(alpha: 0.15)),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(AppColors.primaryValue).withValues(alpha: 0.15),
                    backgroundImage: logoUrl != null ? NetworkImage(logoUrl) : null,
                    child: logoUrl == null
                        ? const Icon(Icons.storefront, size: 16, color: Color(AppColors.primaryValue))
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        if (store.ratingAvg > 0)
                          Row(
                            children: [
                              const Icon(Icons.star, size: 11, color: Colors.amber),
                              Text(' ${store.ratingAvg}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                            ],
                          ),
                      ],
                    ),
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
