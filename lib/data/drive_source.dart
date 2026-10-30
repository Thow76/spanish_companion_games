/// Loads `questions.json` from Google Drive with no sign-in (B8).
///
/// The file is shared as "Anyone with the link can view", so the Drive API
/// returns it with a plain API key. The key and the file ID are never in the
/// code: they are passed in when the app is run or built, e.g.
///
/// ```
/// flutter run -d chrome --web-port 5000 \
///   --dart-define=DRIVE_API_KEY=<key> --dart-define=DRIVE_FILE_ID=<id>
/// ```
///
/// Without both values the app loads the bundled sample file as before.
/// B9 turns the failures below into plain messages for each cause.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/question_parser.dart';

/// The two values passed with `--dart-define`. Both must be set for the app
/// to load from Drive.
class DriveConfig {
  const DriveConfig({required this.apiKey, required this.fileId});

  /// Read from `--dart-define=DRIVE_API_KEY=…` and `DRIVE_FILE_ID=…`.
  const DriveConfig.fromEnvironment()
    : apiKey = const String.fromEnvironment('DRIVE_API_KEY'),
      fileId = const String.fromEnvironment('DRIVE_FILE_ID');

  final String apiKey;
  final String fileId;

  /// True when both values are given.
  bool get isConfigured => apiKey.isNotEmpty && fileId.isNotEmpty;

  /// `https://www.googleapis.com/drive/v3/files/<id>?alt=media&key=<key>`.
  Uri get mediaUri => Uri.https(
    'www.googleapis.com',
    '/drive/v3/files/$fileId',
    {'alt': 'media', 'key': apiKey},
  );
}

/// Shown in the home screen's source line when the questions come from Drive
/// ("15 questions · Google Drive").
const String driveSourceName = 'Google Drive';

/// The Drive request did not return the file.
class DriveLoadException implements Exception {
  const DriveLoadException({this.statusCode, this.cause});

  /// The HTTP status Drive answered with, or null if there was no answer
  /// (no connection, or the browser blocked the request).
  final int? statusCode;

  /// The underlying error when there was no answer.
  final Object? cause;

  @override
  String toString() => statusCode == null
      ? 'Could not reach Google Drive ($cause).'
      : 'Google Drive answered $statusCode.';
}

/// Fetches the question file from Drive and parses it with the usual parser.
///
/// Throws [DriveLoadException] if Drive does not return the file, and
/// [QuestionFileException] (from the parser) if it is not a JSON array.
/// [client] is for tests; by default a new client is made and closed.
Future<ParsedQuestions> loadQuestionsFromDrive(
  DriveConfig config, {
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  try {
    final http.Response response;
    try {
      response = await c.get(config.mediaUri);
    } catch (e) {
      throw DriveLoadException(cause: e);
    }
    if (response.statusCode != 200) {
      throw DriveLoadException(statusCode: response.statusCode);
    }
    // Decode the bytes as UTF-8 ourselves: Drive may not name a charset, and
    // the accents must survive.
    return parseQuestions(utf8.decode(response.bodyBytes));
  } finally {
    if (client == null) c.close();
  }
}
