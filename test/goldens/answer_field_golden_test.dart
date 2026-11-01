/// Gallery screenshots of the AnswerField (U13) and the Spot the error
/// card with its ✓/✗ choice (U17), every state, at the three sizes. UI spec sections 6, 9, 10 and 11.
///
/// `widgets_field_<size>.png`, rendered at the screen's width with that
/// size's layout rules but as tall as its contents:
///
/// - Repair: prefilled with the sentence without marks (resting), focused,
///   edited, a long sentence that wraps, checked right, checked wrong.
/// - Typed Fill the gap: empty, typed, checked right, checked wrong.
/// - Spot the error (U17, spec section 6 of 2026-10-30), the prompt card
///   with the ✓/✗ row inside it: nothing chosen, ✓ chosen, ✗ chosen with
///   the field in place of the sentence, and after checking: ✓ chosen for
///   a correct sentence, ✓ chosen for a wrong one ("Corrected version"),
///   ✗ chosen and fixed ("Corrected version", ✓ dimmed). The buttons keep
///   their colour whether the learner was right or not.
/// - Phone only: the card at 320px wide (the row still fits).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/theme/app_colors.dart';
import 'package:spanish_companion_games/theme/app_layout.dart';
import 'package:spanish_companion_games/theme/app_spacing.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/app_typography.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

import 'golden_helpers.dart';

const _galleryKey = ValueKey('field-gallery');

/// Tall enough for the gallery at every size.
const double _galleryHeight = 3200;

// Sentences from the sample questions, without the marks.
const _repairSentence = 'Esto no hace sentido para mí.';
const _repairFixed = 'Esto no tiene sentido para mí.';
const _repairWrong = 'Esto no hace ningún sentido para mí.';
const _longSentence =
    'El problema es muy difícil y la gente están cansada después de '
    'trabajar todo el día en la oficina, así que nadie quiere hablar.';
const _spotSentence = 'Estoy pensando de mudarme a Glasgow.';
const _spotFixed = 'Estoy pensando en mudarme a Glasgow.';
const _spotWrong = 'Estoy pensando a mudarme a Glasgow.';
const _spotCorrectSentence = 'Depende del tiempo que haga.';

void main() {
  setUpAll(setUpGoldens);

  // A steady cursor, so the focused field looks the same in every run.
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  for (final size in ScreenSize.values) {
    testWidgets('widgets field, ${size.name}', (tester) async {
      tester.view.physicalSize = Size(size.size.width, _galleryHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _GalleryApp(
          size: size,
          child: _FieldGallery(size: size),
        ),
      );
      await settle(tester);

      await expectLater(
        find.byKey(_galleryKey),
        matchesGoldenFile(goldenName('widgets', 'field', size)),
      );
    });
  }
}

/// The app theme for [size], with the media query reporting [size] so the
/// widgets pick that size's layout, and the gallery top-aligned at the
/// screen's width.
class _GalleryApp extends StatelessWidget {
  const _GalleryApp({required this.size, required this.child});

  final ScreenSize size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final formFactor = FormFactor.fromSize(size.size);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(formFactor),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: size.size),
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _galleryKey,
            child: ColoredBox(
              color: AppColors.background,
              child: SizedBox(
                width: size.size.width,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppLayout.sidePadding(formFactor),
                    vertical: AppSpacing.s24,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small heading naming what follows in the gallery.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.s24,
        bottom: AppSpacing.s8,
      ),
      child: Text(
        text,
        style: AppTypography.of(context).chip.copyWith(color: AppColors.accent),
      ),
    );
  }
}

class _FieldGallery extends StatefulWidget {
  const _FieldGallery({required this.size});

  final ScreenSize size;

  @override
  State<_FieldGallery> createState() => _FieldGalleryState();
}

class _FieldGalleryState extends State<_FieldGallery> {
  final _controllers = <TextEditingController>[];

  TextEditingController _text(String text) {
    final c = TextEditingController(text: text);
    _controllers.add(c);
    return c;
  }

  late final _repairResting = _text(_repairSentence);
  late final _repairFocused = _text(_repairSentence);
  late final _repairEdited = _text(_repairFixed);
  late final _repairLong = _text(_longSentence);
  late final _repairRight = _text(_repairFixed);
  late final _repairWrongC = _text(_repairWrong);

  late final _gapEmpty = _text('');
  late final _gapTyped = _text('del');
  late final _gapRight = _text('del');
  late final _gapWrong = _text('de');

  late final _spotOpen = _text(_spotWrong);
  late final _spotNarrow = _text(_spotSentence);

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _repair(
    TextEditingController c, {
    AnswerFieldState state = AnswerFieldState.editing,
    bool autofocus = false,
  }) => AnswerField(
    controller: c,
    state: state,
    autofocus: autofocus,
    caption: AnswerField.repairCaption,
  );

  Widget _gap(
    TextEditingController c, {
    AnswerFieldState state = AnswerFieldState.editing,
  }) => AnswerField(controller: c, state: state);

  Widget _spotField(TextEditingController c) => Builder(
    builder: (context) => AnswerField(
      controller: c,
      textStyle: AppTypography.of(context).prompt,
      semanticLabel: PromptCard.fixLabel,
    ),
  );

  Widget _spotCard({
    required String sentence,
    required SpotErrorPick? picked,
    TextEditingController? field,
    bool checked = false,
    String? corrected,
  }) => PromptCard.spotError(
    sentence: sentence,
    choice: SpotErrorChoice(
      picked: picked,
      onPicked: checked ? null : (_) {},
      checked: checked,
    ),
    field: field == null ? null : _spotField(field),
    corrected: corrected,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Label('Repair: prefilled with the sentence, resting'),
        _repair(_repairResting),
        const _Label('Repair: focused'),
        _repair(_repairFocused, autofocus: true),
        const _Label('Repair: edited'),
        _repair(_repairEdited),
        const _Label('Repair: a long sentence wraps and the field grows'),
        _repair(_repairLong),
        const _Label('Repair: checked, right'),
        _repair(_repairRight, state: AnswerFieldState.correct),
        const _Label('Repair: checked, wrong'),
        _repair(_repairWrongC, state: AnswerFieldState.wrong),

        const _Label('Fill the gap, typed: empty'),
        _gap(_gapEmpty),
        const _Label('Fill the gap, typed: typed'),
        _gap(_gapTyped),
        const _Label('Fill the gap, typed: checked, right'),
        _gap(_gapRight, state: AnswerFieldState.correct),
        const _Label('Fill the gap, typed: checked, wrong'),
        _gap(_gapWrong, state: AnswerFieldState.wrong),

        const _Label('Spot the error: nothing chosen'),
        _spotCard(sentence: _spotSentence, picked: null),
        const _Label('Spot the error: ✓ chosen'),
        _spotCard(sentence: _spotSentence, picked: SpotErrorPick.correct),
        const _Label('Spot the error: ✗ chosen, the sentence is the field'),
        _spotCard(
          sentence: _spotSentence,
          picked: SpotErrorPick.needsFixing,
          field: _spotOpen,
        ),
        const _Label('Checked: correct sentence, ✓ chosen (right)'),
        _spotCard(
          sentence: _spotCorrectSentence,
          picked: SpotErrorPick.correct,
          checked: true,
        ),
        const _Label('Checked: wrong sentence, ✓ chosen (wrong)'),
        _spotCard(
          sentence: _spotSentence,
          picked: SpotErrorPick.correct,
          checked: true,
          corrected: _spotFixed,
        ),
        const _Label('Checked: wrong sentence, ✗ chosen and fixed'),
        _spotCard(
          sentence: _spotSentence,
          picked: SpotErrorPick.needsFixing,
          checked: true,
          corrected: _spotFixed,
        ),

        if (widget.size == ScreenSize.phone) ...[
          const _Label('At 320px wide: ✗ chosen, the row still fits'),
          Align(
            alignment: Alignment.topLeft,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(size: const Size(320, 844)),
              child: SizedBox(
                width: 320 - 2 * AppSpacing.phoneMargin,
                child: _spotCard(
                  sentence: _spotSentence,
                  picked: SpotErrorPick.needsFixing,
                  field: _spotNarrow,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
