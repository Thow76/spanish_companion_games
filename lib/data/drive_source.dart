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
/// Every failure is a [DriveLoadException] with a plain message for its
/// cause (B9).
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

/// Why the questions could not be loaded from Drive (B9). Each has its own
/// plain message in [DriveLoadException.message].
enum DriveProblem {
  /// Drive refused the file (403): it is not shared as "Anyone with the link
  /// can view".
  notShared,

  /// Drive has no such file (404): wrong file ID, or a file that is not
  /// link-shared (Drive answers 404 rather than say it exists).
  notFound,

  /// The API key is not valid, or not allowed to use the Drive API.
  keyRefused,

  /// The key is restricted to other websites than the one the app runs on.
  websiteNotAllowed,

  /// The Drive API is not turned on in the key's Google Cloud project.
  apiNotEnabled,

  /// The file is a Google Docs file, which `alt=media` cannot download.
  googleDocNotFile,

  /// Too many requests for now (rate limit or daily quota).
  tooManyRequests,

  /// Drive answered with a server error (5xx).
  driveUnavailable,

  /// No answer at all: offline, or the request was blocked.
  noConnection,

  /// The file came back but is not JSON.
  notValidJson,

  /// The file is JSON but its top level is not a list of questions.
  notQuestionList,

  /// Any other answer.
  other,
}

/// The questions could not be loaded from Drive.
class DriveLoadException implements Exception {
  const DriveLoadException(
    this.problem, {
    this.statusCode,
    this.reason,
    this.detail,
    this.cause,
  });

  final DriveProblem problem;

  /// The HTTP status Drive answered with, or null if there was no answer
  /// or the file itself was the problem.
  final int? statusCode;

  /// Drive's machine-readable reason (e.g. `keyInvalid`), if it gave one.
  final String? reason;

  /// Drive's own message, or the parser's for a bad file; shown small under
  /// the plain message. Never contains the API key (Drive's messages don't,
  /// and [cause] is never shown, because `http`'s errors include the URL).
  final String? detail;

  /// The underlying error when there was no answer. Not shown on screen.
  final Object? cause;

  /// The plain message for [problem]. [webAddress] is where the app is
  /// running (e.g. `http://localhost:5000`), named in the
  /// [DriveProblem.websiteNotAllowed] message when known.
  String message({String? webAddress}) => switch (problem) {
    DriveProblem.notShared =>
      'Google Drive won\'t let the app read the question file. In Drive, '
          'share questions.json as "Anyone with the link can view", then '
          'reload.',
    DriveProblem.notFound =>
      'Google Drive can\'t find the question file. Check the file ID the '
          'app was run with, and that the file is shared as "Anyone with the '
          'link can view" (Drive hides files that aren\'t).',
    DriveProblem.keyRefused =>
      'Google Drive turned down the API key. Check the key the app was run '
          'with, and that it is allowed to use the Google Drive API.',
    DriveProblem.websiteNotAllowed =>
      webAddress == null
          ? 'Google Drive turned down the API key for this web address. Add '
                'the address to the key\'s website list in Google Cloud, then '
                'reload.'
          : 'Google Drive turned down the API key for this web address. Add '
                '$webAddress/* to the key\'s website list in Google Cloud, '
                'then reload.',
    DriveProblem.apiNotEnabled =>
      'The Google Drive API is not turned on for the API key\'s Google Cloud '
          'project. Turn it on in Google Cloud (APIs & Services), wait a '
          'minute, then reload.',
    DriveProblem.googleDocNotFile =>
      'The question file on Drive is a Google Docs file, not a plain JSON '
          'file. Upload questions.json as a plain file, then reload.',
    DriveProblem.tooManyRequests =>
      'Google Drive says there have been too many requests. Wait a minute, '
          'then reload.',
    DriveProblem.driveUnavailable =>
      'Google Drive isn\'t answering properly just now. Try reloading in a '
          'minute.',
    DriveProblem.noConnection =>
      'Couldn\'t reach Google Drive. Check the internet connection, then '
          'reload.',
    DriveProblem.notValidJson =>
      'The question file on Drive isn\'t valid JSON, so no questions could '
          'be read. Fix the file or upload a fresh export, then reload.',
    DriveProblem.notQuestionList =>
      'The question file on Drive is JSON but not a list of questions. Fix '
          'the file or upload a fresh export, then reload.',
    DriveProblem.other =>
      'Google Drive answered with an error'
          '${statusCode == null ? '' : ' ($statusCode)'}, so no questions '
          'could be loaded. Reload to try again.',
  };

  @override
  String toString() =>
      'DriveLoadException(${problem.name}'
      '${statusCode == null ? '' : ', $statusCode'}'
      '${reason == null ? '' : ', $reason'})';
}

/// Longest [DriveLoadException.detail] kept, so a long error page from
/// Drive can't fill the screen.
const int _maxDetail = 200;

String? _shorten(String? text) {
  if (text == null) return null;
  final t = text.trim();
  if (t.isEmpty) return null;
  return t.length <= _maxDetail ? t : '${t.substring(0, _maxDetail)}…';
}

/// Turns a non-200 answer from Drive into a [DriveLoadException].
///
/// Drive's error body is JSON like
/// `{"error": {"code": 403, "message": "…", "errors": [{"reason": "…"}],
/// "details": [{"@type": "…ErrorInfo", "reason": "…"}]}}`; the reasons are
/// checked before the status, because several causes share 403.
DriveLoadException classifyDriveError(int statusCode, String body) {
  final reasons = <String>[];
  String? driveMessage;
  try {
    final decoded = jsonDecode(body);
    final error = decoded is Map ? decoded['error'] : null;
    if (error is Map) {
      final m = error['message'];
      if (m is String) driveMessage = m;
      final errors = error['errors'];
      if (errors is List) {
        for (final e in errors) {
          if (e is Map && e['reason'] is String) reasons.add(e['reason']);
        }
      }
      final details = error['details'];
      if (details is List) {
        for (final d in details) {
          if (d is Map && d['reason'] is String) reasons.add(d['reason']);
        }
      }
    }
  } on FormatException {
    // Not JSON (an HTML error page, say): go by the status alone.
  }

  bool has(Set<String> names) => reasons.any(names.contains);

  final DriveProblem problem;
  if (has(const {'keyInvalid', 'API_KEY_INVALID'}) ||
      (driveMessage?.contains('API key not valid') ?? false)) {
    problem = DriveProblem.keyRefused;
  } else if (has(const {'API_KEY_HTTP_REFERRER_BLOCKED', 'ipRefererBlocked'})) {
    problem = DriveProblem.websiteNotAllowed;
  } else if (has(const {'API_KEY_SERVICE_BLOCKED'})) {
    // The key is restricted to other APIs than Drive.
    problem = DriveProblem.keyRefused;
  } else if (has(const {'accessNotConfigured', 'SERVICE_DISABLED'})) {
    problem = DriveProblem.apiNotEnabled;
  } else if (has(const {'fileNotDownloadable'})) {
    problem = DriveProblem.googleDocNotFile;
  } else if (statusCode == 429 ||
      has(const {
        'rateLimitExceeded',
        'userRateLimitExceeded',
        'dailyLimitExceeded',
        'quotaExceeded',
        'downloadQuotaExceeded',
        'RATE_LIMIT_EXCEEDED',
      })) {
    problem = DriveProblem.tooManyRequests;
  } else if (statusCode == 404 || has(const {'notFound'})) {
    problem = DriveProblem.notFound;
  } else if (statusCode == 401) {
    problem = DriveProblem.keyRefused;
  } else if (statusCode == 403) {
    problem = DriveProblem.notShared;
  } else if (statusCode >= 500) {
    problem = DriveProblem.driveUnavailable;
  } else {
    problem = DriveProblem.other;
  }

  return DriveLoadException(
    problem,
    statusCode: statusCode,
    reason: reasons.isEmpty ? null : reasons.first,
    detail: _shorten(driveMessage),
  );
}

/// Fetches the question file from Drive and parses it with the usual parser.
///
/// Throws [DriveLoadException] for every failure, including a file that is
/// not JSON or not a list (the parser's [QuestionFileException] becomes
/// [DriveProblem.notValidJson] or [DriveProblem.notQuestionList], with the
/// parser's message as the detail). Invalid individual questions still load
/// as [ParsedQuestions.problems], as before.
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
      throw DriveLoadException(DriveProblem.noConnection, cause: e);
    }
    if (response.statusCode != 200) {
      throw classifyDriveError(
        response.statusCode,
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    }
    // Decode the bytes as UTF-8 ourselves: Drive may not name a charset, and
    // the accents must survive (so no silent replacement characters here).
    final String text;
    try {
      text = utf8.decode(response.bodyBytes);
    } on FormatException {
      throw const DriveLoadException(
        DriveProblem.notValidJson,
        detail: 'The file is not UTF-8 text.',
      );
    }
    try {
      return parseQuestions(text);
    } on QuestionFileException catch (e) {
      final notJson = e.message.startsWith('File is not valid JSON');
      throw DriveLoadException(
        notJson ? DriveProblem.notValidJson : DriveProblem.notQuestionList,
        detail: _shorten(e.message),
      );
    }
  } finally {
    if (client == null) c.close();
  }
}
