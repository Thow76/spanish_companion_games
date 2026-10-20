/// OptionGrid (UI spec section 5): lays out the answer options for Choose a
/// correction and Fill the gap.
///
/// 2 columns below 700px and 4 from 700px, wrapping in rows of 4; if any
/// option is longer than 16 characters, 1 column below 600px and 2 from
/// 600px (phone landscape included). The width is the window's, not the
/// column's, so phone landscape (844) and laptop get 4 across. Options in
/// one row share the height of the tallest, so a phrase that wraps makes
/// its whole row grow; nothing is truncated.
library;

import 'package:flutter/material.dart';

import '../theme/app_layout.dart';
import 'answer_option.dart';

class OptionGrid extends StatelessWidget {
  const OptionGrid({
    super.key,
    required this.children,
    required this.phrases,
    this.semanticLabel = 'Options',
  });

  /// Builds a grid from labels, working out [phrases] from them.
  OptionGrid.forLabels({
    super.key,
    required List<String> labels,
    required Widget Function(String label) builder,
    this.semanticLabel = 'Options',
  }) : children = [for (final l in labels) builder(l)],
       phrases = AnswerOption.anyPhrase(labels);

  /// Usually [AnswerOption]s.
  final List<Widget> children;

  /// True when any option is phrase-length ([AnswerOption.anyPhrase]).
  final bool phrases;

  /// Read by screen readers for the group.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final columns = AppLayout.optionColumns(
      MediaQuery.sizeOf(context).width,
      count: children.length,
      phrases: phrases,
    );
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      final cells = <Widget>[];
      for (var c = 0; c < columns; c++) {
        if (c > 0) cells.add(const SizedBox(width: AppLayout.optionGap));
        final i = start + c;
        // A short last row keeps the column widths: empty cells fill it.
        cells.add(
          Expanded(child: i < children.length ? children[i] : const SizedBox()),
        );
      }
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: AppLayout.optionGap));
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}
