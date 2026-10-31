import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:spanish_companion_games/data/drive_source.dart';

const _config = DriveConfig(apiKey: 'test-key', fileId: 'test-file');

const _oneQuestion = '''
[
  {
    "id": "2026-10-30-001",
    "phase": 2,
    "game": "fill_gap",
    "type": "grammar",
    "category": "Prepositions",
    "prompt": "Sueño ___ viajar a México.",
    "answers": ["con"],
    "explanation": "soñar con = to dream of",
    "source": "Test",
    "added": "2026-10-30"
  }
]
''';

void main() {
  test('isConfigured needs both values', () {
    expect(_config.isConfigured, isTrue);
    expect(const DriveConfig(apiKey: '', fileId: 'x').isConfigured, isFalse);
    expect(const DriveConfig(apiKey: 'x', fileId: '').isConfigured, isFalse);
  });

  test('without --dart-define the app is not configured for Drive', () {
    expect(const DriveConfig.fromEnvironment().isConfigured, isFalse);
  });

  test('asks Drive for the file contents with the key', () {
    final uri = _config.mediaUri;
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.googleapis.com');
    expect(uri.path, '/drive/v3/files/test-file');
    expect(uri.queryParameters, {'alt': 'media', 'key': 'test-key'});
  });

  test('parses the file and keeps the accents', () async {
    late Uri asked;
    final client = MockClient((request) async {
      asked = request.url;
      // No charset in the content type, as Drive may answer.
      return http.Response.bytes(
        utf8.encode(_oneQuestion),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final parsed = await loadQuestionsFromDrive(_config, client: client);
    expect(asked, _config.mediaUri);
    expect(parsed.questions, hasLength(1));
    expect(parsed.questions.single.prompt, 'Sueño ___ viajar a México.');
    expect(parsed.problems, isEmpty);
  });

  test('a refused request throws DriveLoadException with the status', () async {
    final client = MockClient((_) async => http.Response('denied', 403));
    await expectLater(
      loadQuestionsFromDrive(_config, client: client),
      throwsA(
        isA<DriveLoadException>()
            .having((e) => e.statusCode, 'status', 403)
            .having((e) => e.problem, 'problem', DriveProblem.notShared),
      ),
    );
  });

  test('no connection throws noConnection, and never shows the key', () async {
    final client = MockClient(
      (request) async =>
          throw http.ClientException('XMLHttpRequest error.', request.url),
    );
    try {
      await loadQuestionsFromDrive(_config, client: client);
      fail('should have thrown');
    } on DriveLoadException catch (e) {
      expect(e.problem, DriveProblem.noConnection);
      expect(e.statusCode, isNull);
      expect(e.detail, isNull);
      expect(e.message(), isNot(contains('test-key')));
      expect(e.toString(), isNot(contains('test-key')));
    }
  });

  test('a file that is not JSON throws notValidJson', () async {
    final client = MockClient((_) async => http.Response('<html>', 200));
    await expectLater(
      loadQuestionsFromDrive(_config, client: client),
      throwsA(
        isA<DriveLoadException>()
            .having((e) => e.problem, 'problem', DriveProblem.notValidJson)
            .having((e) => e.detail, 'detail', startsWith('File is not valid')),
      ),
    );
  });

  test('JSON that is not a list throws notQuestionList', () async {
    final client = MockClient((_) async => http.Response('{"a": 1}', 200));
    await expectLater(
      loadQuestionsFromDrive(_config, client: client),
      throwsA(
        isA<DriveLoadException>().having(
          (e) => e.problem,
          'problem',
          DriveProblem.notQuestionList,
        ),
      ),
    );
  });

  test('bytes that are not UTF-8 throw notValidJson', () async {
    final client = MockClient(
      (_) async => http.Response.bytes([0x5B, 0xFF, 0x5D], 200),
    );
    await expectLater(
      loadQuestionsFromDrive(_config, client: client),
      throwsA(
        isA<DriveLoadException>().having(
          (e) => e.problem,
          'problem',
          DriveProblem.notValidJson,
        ),
      ),
    );
  });

  group('classifyDriveError', () {
    String body(int code, String message, {String? reason, String? info}) =>
        jsonEncode({
          'error': {
            'code': code,
            'message': message,
            if (reason != null)
              'errors': [
                {'message': message, 'domain': 'global', 'reason': reason},
              ],
            if (info != null)
              'details': [
                {
                  '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
                  'reason': info,
                  'domain': 'googleapis.com',
                },
              ],
          },
        });

    test('file not link-shared (403)', () {
      final e = classifyDriveError(
        403,
        body(
          403,
          'The user does not have sufficient permissions for file.',
          reason: 'insufficientFilePermissions',
        ),
      );
      expect(e.problem, DriveProblem.notShared);
      expect(e.reason, 'insufficientFilePermissions');
      expect(e.detail, startsWith('The user does not have'));
    });

    test('file not found (404)', () {
      final e = classifyDriveError(
        404,
        body(404, 'File not found: test-file.', reason: 'notFound'),
      );
      expect(e.problem, DriveProblem.notFound);
    });

    test('key not valid (400)', () {
      final e = classifyDriveError(
        400,
        body(
          400,
          'API key not valid. Please pass a valid API key.',
          reason: 'badRequest',
          info: 'API_KEY_INVALID',
        ),
      );
      expect(e.problem, DriveProblem.keyRefused);
    });

    test('key restricted to other APIs', () {
      final e = classifyDriveError(
        403,
        body(
          403,
          'Requests to this API are blocked.',
          info: 'API_KEY_SERVICE_BLOCKED',
        ),
      );
      expect(e.problem, DriveProblem.keyRefused);
    });

    test('key restricted to other websites', () {
      final e = classifyDriveError(
        403,
        body(
          403,
          'Requests from referer http://localhost:5001/ are blocked.',
          reason: 'forbidden',
          info: 'API_KEY_HTTP_REFERRER_BLOCKED',
        ),
      );
      expect(e.problem, DriveProblem.websiteNotAllowed);
      expect(
        e.message(webAddress: 'http://localhost:5001'),
        contains('http://localhost:5001/*'),
      );
      expect(e.message(), isNot(contains('null')));
    });

    test('Drive API not turned on', () {
      final e = classifyDriveError(
        403,
        body(
          403,
          'Google Drive API has not been used in project 123.',
          reason: 'accessNotConfigured',
          info: 'SERVICE_DISABLED',
        ),
      );
      expect(e.problem, DriveProblem.apiNotEnabled);
    });

    test('a Google Docs file', () {
      final e = classifyDriveError(
        403,
        body(
          403,
          'Only files with binary content can be downloaded.',
          reason: 'fileNotDownloadable',
        ),
      );
      expect(e.problem, DriveProblem.googleDocNotFile);
    });

    test('too many requests', () {
      expect(
        classifyDriveError(
          403,
          body(403, 'Rate limit exceeded.', reason: 'userRateLimitExceeded'),
        ).problem,
        DriveProblem.tooManyRequests,
      );
      expect(classifyDriveError(429, '').problem, DriveProblem.tooManyRequests);
    });

    test('server error, HTML body', () {
      final e = classifyDriveError(503, '<html>Service Unavailable</html>');
      expect(e.problem, DriveProblem.driveUnavailable);
      expect(e.detail, isNull);
    });

    test('anything else names the status', () {
      final e = classifyDriveError(418, '');
      expect(e.problem, DriveProblem.other);
      expect(e.message(), contains('(418)'));
    });

    test('a long message is cut short', () {
      final e = classifyDriveError(403, body(403, 'x' * 500));
      expect(e.detail!.length, lessThanOrEqualTo(201));
    });
  });

  test('every problem has its own message', () {
    final messages = {
      for (final p in DriveProblem.values) DriveLoadException(p).message(),
    };
    expect(messages, hasLength(DriveProblem.values.length));
  });
}
