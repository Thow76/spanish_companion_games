import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'theme/form_factor.dart';

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
      theme: appTheme(FormFactor.phone),
      // Type sizes depend on the screen size (UI spec section 3), so the
      // theme follows the current form factor.
      builder: (context, child) => Theme(
        data: appTheme(FormFactor.of(context)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }
}
