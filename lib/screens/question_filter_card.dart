/// The question filter card (B12), shared by the home screen and the set
/// picker (B24).
///
/// A quiet card like the skipped-questions notice. Shut, it reads
/// "Filter: All questions" (or what is chosen, with "5 of 15 questions"
/// under it); open, it shows rows of choices, Type, Phase (home only, see
/// [showPhase]) and Category, each starting with "All". The chosen one in
/// each row is highlighted.
///
/// The spec has no filter control; the choices use WordChip (the closest
/// shared widget: a tappable chip with a highlighted state).
library;

import 'package:flutter/material.dart';

import '../models/question.dart';
import '../models/question_filter.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/widgets.dart';

class QuestionFilterCard extends StatelessWidget {
  const QuestionFilterCard({
    super.key,
    required this.filter,
    required this.categories,
    required this.shownCount,
    required this.totalCount,
    required this.onChanged,
    this.showPhase = true,
  });

  final QuestionFilter filter;
  final List<String> categories;
  final int shownCount;
  final int totalCount;
  final ValueChanged<QuestionFilter> onChanged;

  /// Whether the Phase row shows. The set picker (B24) already belongs to
  /// one phase, so it leaves it out.
  final bool showPhase;

  static const String allLabel = 'All';
  static const String noMatchText =
      'No questions match this filter. Choose "All" in a row to widen it.';

  static String countText(int shown, int total) =>
      '$shown of ${total == 1 ? '1 question' : '$total questions'}';

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    // Without the Phase row, a phase chosen on home is not this card's to
    // show: leave it out of the heading.
    final shownFilter = showPhase ? filter : filter.withPhase(null);

    Widget row<T>(
      String label,
      List<T> values,
      String Function(T) labelOf,
      T? chosen,
      bool Function(T, T) same,
      QuestionFilter Function(T?) change,
    ) {
      Widget chip(String text, bool selected, T? value) => WordChip(
        key: ValueKey('filter-$label-$text'),
        label: text,
        state: selected ? WordChipState.placed : WordChipState.toPlace,
        onPressed: selected ? null : () => onChanged(change(value)),
      );
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(label, style: type.caption)),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                chip(allLabel, chosen == null, null),
                for (final v in values)
                  chip(labelOf(v), chosen != null && same(v, chosen), v),
              ],
            ),
          ],
        ),
      );
    }

    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: AppColors.textMuted,
        collapsedIconColor: AppColors.textMuted,
        leading: Icon(
          Icons.filter_list_rounded,
          size: AppSizes.iconSmall,
          color: shownFilter.isAll ? AppColors.textMuted : AppColors.accent,
        ),
        title: Text(
          'Filter: ${shownFilter.summary}',
          style: type.caption.copyWith(color: AppColors.textSecondary),
        ),
        subtitle: shownFilter.isAll
            ? null
            : Text(countText(shownCount, totalCount), style: type.caption),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          0,
          AppSpacing.s16,
          AppSpacing.s16,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row<QuestionType>(
            'Type',
            QuestionType.values,
            QuestionFilter.typeLabel,
            filter.type,
            (a, b) => a == b,
            filter.withType,
          ),
          if (showPhase)
            row<QuestionPhase>(
              'Phase',
              QuestionPhase.values,
              (p) => p.label,
              filter.phase,
              (a, b) => a == b,
              filter.withPhase,
            ),
          if (categories.isNotEmpty)
            row<String>(
              'Category',
              categories,
              (c) => c,
              filter.category,
              (a, b) => a.trim().toLowerCase() == b.trim().toLowerCase(),
              filter.withCategory,
            ),
        ],
      ),
    );
  }
}
