/// Behaviour of the end-of-session summary (B7): the round's score, the
/// session score split into new corrections and recall, the questions got
/// wrong with their explanations, "Play again", and a game screen feeding
/// the shared tally.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/session_tally.dart';
import 'package:spanish_companion_games/screens/choose_correction_screen.dart';
import 'package:spanish_companion_games/screens/session_summary_view.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

// Two choose_correction questions from assets/questions.sample.json.
Question _pensando() => Question(
  id: '2026-10-17-001',
  game: GameType.chooseCorrection,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Estoy pensando **de** cambiar de trabajo.',
  answers: const ['en'],
  options: const ['en', 'a', 'por'],
  explanation: 'pensar en + infinitive = to be thinking of doing something',
);

Question _hermana() => Question(
  id: '2026-10-17-002',
  game: GameType.chooseCorrection,
  category: 'Ser/estar',
  type: QuestionType.grammar,
  prompt: 'Mi hermana **es** muy cansada hoy.',
  answers: const ['está'],
  options: const ['está', 'estaba', 'sea'],
  explanation: 'estar cansado = to be tired (a state right now, so estar)',
);

// A fill_gap question from the sample, for the recall line.
Question _depende() => Question(
  id: '2026-10-17-008',
  game: GameType.fillGap,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Depende ___ tiempo que haga.',
  answers: const ['del'],
  options: const ['del', 'de', 'en', 'al'],
  explanation: 'depender de = to depend on',
);

Widget _app(Widget home) => MaterialApp(
  theme: appTheme(FormFactor.phone),
  builder: (context, child) => Theme(
    data: appTheme(FormFactor.of(context)),
    child: child ?? const SizedBox.shrink(),
  ),
  home: home,
);

SessionSummaryView _summary({
  required List<Question> questions,
  required List<bool?> results,
  SessionTally? session,
  VoidCallback? onPlayAgain,
}) => SessionSummaryView(
  game: GameType.chooseCorrection,
  questions: questions,
  results: results,
  session: session,
  onPlayAgain: onPlayAgain ?? () {},
  onBack: () {},
);

/// The text of the score line for a phase, e.g. "1 of 2 right".
String _phaseScore(WidgetTester tester, QuestionPhase phase) {
  final row = find.ancestor(
    of: find.text(phase.label),
    matching: find.byType(Wrap),
  );
  final texts = tester
      .widgetList<Text>(
        find.descendant(of: row.first, matching: find.byType(Text)),
      )
      .map((t) => t.data)
      .toList();
  return texts.last ?? '';
}

void main() {
  testWidgets('shows the round score, both phases and the wrong question', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _summary(questions: [_pensando(), _hermana()], results: [true, false]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(SessionSummaryView.title), findsOneWidget);
    expect(find.text('You got 1 of 2 right.'), findsOneWidget);
    expect(find.text(SessionSummaryView.sessionHeading), findsOneWidget);
    expect(_phaseScore(tester, QuestionPhase.noticeAndCorrect), '1 of 2 right');
    expect(_phaseScore(tester, QuestionPhase.recall), 'None yet');

    expect(find.text(SessionSummaryView.wrongHeading), findsOneWidget);
    // Only the wrong question is listed, with its explanation.
    expect(find.byType(PromptCard), findsOneWidget);
    expect(
      tester.widget<PromptCard>(find.byType(PromptCard)).corrected,
      'Mi hermana está muy cansada hoy.',
    );
    expect(find.byType(ExplanationCard), findsOneWidget);
  });

  testWidgets('all right: no list, a short line instead', (tester) async {
    await tester.pumpWidget(
      _app(
        _summary(questions: [_pensando(), _hermana()], results: [true, true]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You got 2 of 2 right.'), findsOneWidget);
    expect(find.text(SessionSummaryView.allRightText), findsOneWidget);
    expect(find.text(SessionSummaryView.wrongHeading), findsNothing);
    expect(find.byType(PromptCard), findsNothing);
  });

  testWidgets('the session line counts other games from the shared tally', (
    tester,
  ) async {
    final session = SessionTally()
      ..record(_depende(), true)
      ..record(_pensando(), true)
      ..record(_hermana(), false);
    await tester.pumpWidget(
      _app(
        _summary(
          questions: [_pensando(), _hermana()],
          results: [true, false],
          session: session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_phaseScore(tester, QuestionPhase.noticeAndCorrect), '1 of 2 right');
    expect(_phaseScore(tester, QuestionPhase.recall), '1 of 1 right');
  });

  testWidgets('Play again calls back', (tester) async {
    var played = 0;
    await tester.pumpWidget(
      _app(
        _summary(
          questions: [_pensando()],
          results: [false],
          onPlayAgain: () => played++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Play again'));
    await tester.pumpAndSettle();
    expect(played, 1);
  });

  testWidgets('a game screen records each check in the shared tally', (
    tester,
  ) async {
    final session = SessionTally();
    await tester.pumpWidget(
      _app(
        ChooseCorrectionScreen(
          questions: [_pensando(), _hermana()],
          session: session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AnswerOption, 'en'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    // Let the toast go, as the other screen tests do.
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(session.scoreFor(QuestionPhase.noticeAndCorrect), (
      right: 1,
      answered: 1,
    ));
  });

  group('Copy results (B17)', () {
    String? copied;
    var failClipboard = false;

    setUp(() {
      copied = null;
      failClipboard = false;
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              if (failClipboard) {
                throw PlatformException(code: 'denied');
              }
              copied = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('copies every question from the shared tally and says so', (
      tester,
    ) async {
      final day = DateTime(2026, 11, 1, 10);
      final session = SessionTally(clock: () => day)
        ..record(_depende(), true)
        ..record(_pensando(), true)
        ..record(_hermana(), false);
      await tester.pumpWidget(
        _app(
          _summary(
            questions: [_pensando(), _hermana()],
            results: [true, false],
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.text(CopyResultsButton.label);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(
        copied,
        'Spanish Games results 2026-11-01\n'
        '2026-10-17-008, fill_gap, right, 2026-11-01\n'
        '2026-10-17-001, choose_correction, right, 2026-11-01\n'
        '2026-10-17-002, choose_correction, wrong, 2026-11-01',
      );
      expect(find.text(CopyResultsButton.copiedText(3)), findsOneWidget);
      expect(find.text(CopyResultsButton.againLabel), findsOneWidget);
      expect(find.text(CopyResultsButton.label), findsNothing);
    });

    testWidgets('without a shared tally it copies this round', (tester) async {
      await tester.pumpWidget(
        _app(_summary(questions: [_pensando()], results: [false])),
      );
      await tester.pumpAndSettle();
      final button = find.text(CopyResultsButton.label);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      final lines = copied!.split('\n');
      expect(lines, hasLength(2));
      expect(lines.first, startsWith('Spanish Games results '));
      expect(
        lines.last,
        startsWith('2026-10-17-001, choose_correction, wrong, '),
      );
      expect(find.text(CopyResultsButton.copiedText(1)), findsOneWidget);
    });

    testWidgets('a clipboard failure is reported, not hidden', (tester) async {
      failClipboard = true;
      await tester.pumpWidget(
        _app(_summary(questions: [_pensando()], results: [true])),
      );
      await tester.pumpAndSettle();
      final button = find.text(CopyResultsButton.label);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text(CopyResultsButton.failedText), findsOneWidget);
      expect(find.text(CopyResultsButton.label), findsOneWidget);
    });

    testWidgets('on laptop it sits in the side panel under Play again', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          _summary(
            questions: [_pensando(), _hermana()],
            results: [false, false],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CopyResultsButton.label), findsOneWidget);
      final play = tester.getRect(
        find.widgetWithText(PrimaryButton, 'Play again'),
      );
      final copy = tester.getRect(find.byType(CopyResultsButton));
      expect(copy.top, greaterThan(play.bottom));
      expect(copy.left, closeTo(play.left, 1));
      // On screen, however long the list.
      expect(copy.bottom, lessThanOrEqualTo(800));
    });
  });
}
