/// Loads question files into [ParsedQuestions].
library;

import 'package:flutter/services.dart' show rootBundle;

import '../models/question_parser.dart';

/// Path of the bundled sample file (registered in `pubspec.yaml`).
const String sampleQuestionsAsset = 'assets/questions.sample.json';

/// Loads and parses a question file bundled as a Flutter asset.
///
/// Defaults to the sample file. Throws [QuestionFileException] if the file is
/// not a JSON array; invalid individual questions are reported in
/// [ParsedQuestions.problems].
Future<ParsedQuestions> loadQuestionsFromAsset([
  String assetPath = sampleQuestionsAsset,
]) async {
  final text = await rootBundle.loadString(assetPath);
  return parseQuestions(text);
}
