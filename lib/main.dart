import 'package:flutter/material.dart';

import 'data/drive_source.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'theme/form_factor.dart';

void main() {
  runApp(const SpanishGamesApp());
}

/// The Drive key and file ID, if the app was run or built with them (B8).
/// Without them the home screen loads the bundled sample file.
const DriveConfig _drive = DriveConfig.fromEnvironment();

/// Root of the app: theme plus the home screen.
class SpanishGamesApp extends StatelessWidget {
  const SpanishGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spanish Companion Games',
      debugShowCheckedModeBanner: false,
      theme: appTheme(FormFactor.phone),
      // Type sizes depend on the screen size (UI spec section 3), so the
      // theme follows the current form factor.
      builder: (context, child) => Theme(
        data: appTheme(FormFactor.of(context)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: _drive.isConfigured
          ? HomeScreen(
              source: () => loadQuestionsFromDrive(_drive),
              sourceName: driveSourceName,
            )
          : const HomeScreen(),
    );
  }
}
