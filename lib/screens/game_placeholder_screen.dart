/// Stand-in for the game screens that B3–B6 will add.
///
/// Shows the game name and the number of questions available so that the home
/// screen can be tested end to end before the games exist. Each game item
/// replaces the route pushed from `HomeScreen._openGame` with its real screen.
library;

import 'package:flutter/material.dart';

import '../models/question.dart';

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
