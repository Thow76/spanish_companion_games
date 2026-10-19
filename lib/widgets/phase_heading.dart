/// PhaseHeading (UI spec sections 6 and 8): the home screen's group title
/// ("New corrections" or "Recall") with a one-line description under it.
/// 24 above (16 above the first group on phone), 12 below. A real heading
/// for screen readers.
library;

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';

class PhaseHeading extends StatelessWidget {
  const PhaseHeading({
    super.key,
    required this.title,
    required this.description,
    this.first = false,
  });

  /// Phase 1: "New corrections".
  const PhaseHeading.newCorrections({super.key, this.first = true})
    : title = 'New corrections',
      description = 'Your own mistakes, marked. Put them right.';

  /// Phase 2: "Recall".
  const PhaseHeading.recall({super.key, this.first = false})
    : title = 'Recall',
      description = "Points you've corrected, in new sentences.";

  final String title;
  final String description;

  /// The first group on the screen: 16 above on phone instead of 24.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final phone = FormFactor.of(context) != FormFactor.laptop;
    return Padding(
      padding: EdgeInsets.only(
        top: first && phone ? AppSpacing.s16 : AppSpacing.s24,
        bottom: AppSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: type.phaseHeading)),
          const SizedBox(height: AppSpacing.s4),
          Text(description, style: type.caption),
        ],
      ),
    );
  }
}
