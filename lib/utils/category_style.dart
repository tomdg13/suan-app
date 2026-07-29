import 'package:flutter/material.dart';
import '../config/constants.dart';

/// Maps a category's English name to a representative icon. Falls back
/// sensibly for any category name we don't recognize.
IconData categoryIcon(String? nameEn) {
  final name = (nameEn ?? '').toLowerCase();
  if (name.contains('veg')) return Icons.grass;
  if (name.contains('fruit')) return Icons.local_florist;
  if (name.contains('fish') || name.contains('aquatic')) return Icons.set_meal;
  if (name.contains('poultry') || name.contains('egg')) return Icons.egg;
  if (name.contains('rice') || name.contains('grain')) return Icons.rice_bowl;
  if (name.contains('processed')) return Icons.inventory_2;
  if (name.contains('equipment') || name.contains('farm')) return Icons.agriculture;
  return Icons.category;
}

/// Single, cohesive tint for every category tile — a soft wash of the
/// brand green — rather than a rainbow of unrelated pastel colors.
/// Keeps the whole screen reading as one deliberate palette.
Color categoryTileColor() => const Color(AppColors.primaryValue).withValues(alpha: 0.08);
