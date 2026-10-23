/// Stand-in for the game screens that B3–B6 will add.
///
/// Shows the game name and the number of questions available so that the home
/// screen can be tested end to end before the games exist. Each game item
/// replaces the route pushed from `HomeScreen._openGame` with its real screen.
///
/// Repair the sentence (B5) is opened from here for now: B5 was built while
/// the UI task's PR #12 was changing `home_screen.dart`, so the build task
/// kept out of that file. Once #12 is merged, a later build item moves the
/// `GameType.repair` case into `HomeScreen._openGame` next to Choose a
/// correction.
library;

import 'package:flutter/material.dart';

import '../models/question.dart';
import 'repair_screen.dart';

class GamePlaceholderScreen extends StatelessWidget {
  const GamePlaceholderScreen({
    super.key,
    required this.game,
    required this.questions,
  });

  final GameType game;
  final List<Question> questions;

  @override
  Widget build(BuildContext context) {
    // The games built since the home screen last changed (see above).
    if (game == GameType.repair) {
      return RepairScreen(questions: questions);
    }
    final n = questions.length;
    return Scaffold(
      appBar: AppBar(title: Text(game.label)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                n == 1 ? '1 question ready' : '$n questions ready',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'This game is built in a later step.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to games'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
