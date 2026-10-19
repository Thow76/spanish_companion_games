/// Count and CategoryChip (UI spec section 6 and 8).
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// "Question 2 of 3", muted caption. The only progress indicator: on the
/// chip row on phones (both orientations), in the top bar on laptop.
class Count extends StatelessWidget {
  const Count({super.key, required this.current, required this.total});

  /// 1-based number of the question on screen.
  final int current;
  final int total;

  static String text(int current, int total) => 'Question $current of $total';

  @override
  Widget build(BuildContext context) {
    return Text(
      text(current, total),
      style: AppTypography.of(context).caption,
      textAlign: TextAlign.end,
    );
  }
}

/// The question's type and category: "Grammar error · Prepositions" or
/// "Language note · Calque". Chip style; no colour per type or category.
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.type, required this.category});

  /// The `type` value: `grammar` or `note`. Anything else shows the
  /// category only.
  final String type;

  /// The `category` value, shown as written.
  final String category;

  /// "Grammar error" for `grammar`, "Language note" for `note`.
  static String? typeLabel(String type) => switch (type) {
    'grammar' => 'Grammar error',
    'note' => 'Language note',
    _ => null,
  };

  static String text(String type, String category) {
    final label = typeLabel(type);
    if (label == null) return category;
    if (category.trim().isEmpty) return label;
    return '$label · $category';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppInsets.chip,
      decoration: BoxDecoration(
        color: AppColors.fillChip,
        borderRadius: AppRadius.chipAll,
        border: Border.all(color: AppColors.stroke),
      ),
      child: Text(
        text(type, category),
        style: AppTypography.of(context).chip,
        softWrap: true,
      ),
    );
  }
}

/// The row above the prompt card on phones (both orientations): the
/// category chip on the left, "Question 2 of 3" right-aligned.
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.type,
    required this.category,
    required this.current,
    required this.total,
  });

  final String type;
  final String category;
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: CategoryChip(type: type, category: category),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Count(current: current, total: total),
      ],
    );
  }
}
