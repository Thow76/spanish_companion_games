/// Screenshots of the home screen when the questions could not be loaded
/// from Google Drive (B9), at the three sizes. UI spec sections 5, 6 and 11.
///
/// - `home-drive-error_not-shared_<size>`: the file is not link-shared; the
///   plain message with Drive's own words in a smaller line under it.
/// - `home-drive-error_website_<size>`: the API key does not allow the web
///   address the app runs on (the longest message).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/data/drive_source.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';

import 'golden_helpers.dart';

void main() {
  setUpAll(setUpGoldens);

  final cases = <String, DriveLoadException>{
    'not-shared': const DriveLoadException(
      DriveProblem.notShared,
      statusCode: 403,
      reason: 'insufficientFilePermissions',
      detail:
          'The user does not have sufficient permissions for file '
          '1AbCdEfGhIjKlMnOpQrStUvWxYz.',
    ),
    'website': const DriveLoadException(
      DriveProblem.websiteNotAllowed,
      statusCode: 403,
      reason: 'API_KEY_HTTP_REFERRER_BLOCKED',
      detail:
          'Requests from referer https://spanish-games.web.app/ are '
          'blocked.',
    ),
  };

  for (final size in ScreenSize.values) {
    for (final entry in cases.entries) {
      testWidgets('home, Drive error ${entry.key}, ${size.name}', (
        tester,
      ) async {
        setScreenSize(tester, size);
        await tester.pumpWidget(
          _App(child: HomeScreen(source: () async => throw entry.value)),
        );
        await settle(tester);
        await expectLater(
          find.byType(_App),
          matchesGoldenFile(goldenName('home-drive-error', entry.key, size)),
        );
      });
    }
  }
}

/// The app's theme around [child], without the debug banner.
class _App extends StatelessWidget {
  const _App({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(FormFactor.phone),
      builder: (context, child) => Theme(
        data: appTheme(FormFactor.of(context)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: child,
    );
  }
}
