import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:spanish_companion_games/data/drive_source.dart';
import 'package:spanish_companion_games/models/question_parser.dart';

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
        isA<DriveLoadException>().having((e) => e.statusCode, 'status', 403),
      ),
    );
  });

  test('no connection throws DriveLoadException without a status', () async {
    final client = MockClient((_) async => throw Exception('offline'));
    await expectLater(
      loadQuestionsFromDrive(_config, client: client),
      throwsA(
        isA<DriveLoadException>().having((e) => e.statusCode, 'status', null),
      ),
    );
  });

  test('a file that is not JSON throws QuestionFileException', () async {
    final client = MockClient((_) async => http.Response('<html>', 200));
    await expectLater(
      loadQuestionsFromDrive(_config, client: client),
      throwsA(isA<QuestionFileException>()),
    );
  });
}
