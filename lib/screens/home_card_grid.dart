/// Home-style cards in a grid, shared by the home screen and the set picker.
library;

import 'package:flutter/material.dart';

import '../theme/app_layout.dart';

/// Home-style cards: one column on phones, a 2-column grid on laptop
/// (cards in a row share their height, so "Play →" lines up at the
/// bottom). Used by the home screen's two choices and by
/// the set picker (B24).
class HomeCardGrid extends StatelessWidget {
  const HomeCardGrid({super.key, required this.cards, required this.laptop});

  final List<Widget> cards;
  final bool laptop;

  @override
  Widget build(BuildContext context) {
    if (!laptop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: AppLayout.phoneCardGap),
            cards[i],
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppLayout.laptopCardGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: AppLayout.laptopCardGap),
                Expanded(
                  child: i + 1 < cards.length
                      ? cards[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
