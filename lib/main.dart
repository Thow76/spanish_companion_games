import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const SpanishGamesApp());
}

/// Root of the app: theme plus the home screen.
class SpanishGamesApp extends StatelessWidget {
  const SpanishGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spanish Companion Games',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
