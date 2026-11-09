/// Sends each checked question's result to the Test Review sheet (B18).
///
/// The sheet's Apps Script is deployed as a web app ("Execute as: me",
/// "Who has access: anyone"). Its `/exec` address is passed in when the app
/// is run or built, never written in the code:
///
/// ```
/// flutter run -d chrome --web-port 5000 --dart-define-from-file=drive.json
/// ```
///
/// with `"RESULTS_URL": "https://script.google.com/macros/s/…/exec"` in
/// `drive.json`, or `--dart-define=RESULTS_URL=…`. Without it nothing is
/// sent and "Copy results" (B17) is the only way to record results.
///
/// Every result is sent as soon as the question is checked, so closing the
/// tab mid-round loses nothing that was already sent. A failed send keeps
/// the result pending; the next check, or "Send again" on the summary,
/// sends everything still pending in one request. The script writes a
/// result for the same item on the same day over the earlier one, so
/// sending twice does no harm.
///
/// Body (POST, `text/plain` so the browser sends it without a CORS
/// preflight, which Apps Script cannot answer):
///
/// ```json
/// {"results": [
///   {"id": "FB-0001", "game": "fill_gap", "phase": 2, "right": true,
///    "date": "2026-11-04"}
/// ]}
/// ```
///
/// B22: a Repair question right only after the hint is sent as
/// `"right": false, "hinted": true` (the field is left out otherwise). The
/// script ignores `hinted` for now, so the item counts as not passed.
///
/// The script answers `{"ok": true, "saved": ["FB-0001"], "unknown": []}`.
/// `unknown` lists ids with no row in the sheet (e.g. the sample file's
/// ids); they are not sent again.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/session_tally.dart';

/// The web app address passed with `--dart-define=RESULTS_URL=…`.
class ResultsConfig {
  const ResultsConfig(this.url);

  const ResultsConfig.fromEnvironment()
    : url = const String.fromEnvironment('RESULTS_URL');

  final String url;

  bool get isConfigured => url.isNotEmpty;
}

/// Where the sending stands, for the summary's status line.
enum ResultsSyncState {
  /// Nothing sent yet.
  idle,

  /// A request is on its way.
  sending,

  /// Everything checked so far is in the sheet.
  saved,

  /// The last request failed; [ResultsSync.pending] results wait.
  failed,
}

class ResultsSync extends ChangeNotifier {
  ResultsSync(this.config, {http.Client? client})
    : _client = client ?? http.Client();

  final ResultsConfig config;
  final http.Client _client;

  /// Results not yet confirmed by the sheet, by question id (latest result
  /// per id, as in the tally).
  final Map<String, TallyEntry> _pending = {};

  /// Ids the sheet confirmed, and ids it had no row for.
  final Set<String> _saved = {};
  final Set<String> _unknown = {};

  ResultsSyncState _state = ResultsSyncState.idle;
  bool _again = false;

  ResultsSyncState get state => _state;
  int get pending => _pending.length;
  int get saved => _saved.length;

  /// Ids the sheet has no row for (not sent again).
  Set<String> get unknown => Set.unmodifiable(_unknown);

  /// Queues one checked question and sends everything pending.
  void add(TallyEntry entry) {
    if (!config.isConfigured || _unknown.contains(entry.id)) return;
    _pending[entry.id] = entry;
    _saved.remove(entry.id);
    unawaited(send());
  }

  /// Sends everything pending in one request. While a request is on its
  /// way, a second call waits for it and then sends what is left.
  Future<void> send() async {
    if (_pending.isEmpty) return;
    if (_state == ResultsSyncState.sending) {
      _again = true;
      return;
    }
    final batch = Map<String, TallyEntry>.of(_pending);
    _setState(ResultsSyncState.sending);
    var ok = false;
    try {
      final response = await _client
          .post(
            Uri.parse(config.url),
            headers: {'Content-Type': 'text/plain;charset=utf-8'},
            body: jsonEncode(bodyFor(batch.values)),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final answer = jsonDecode(utf8.decode(response.bodyBytes));
        if (answer is Map && answer['ok'] == true) {
          final saved = _ids(answer['saved']);
          final unknown = _ids(answer['unknown']);
          for (final id in batch.keys) {
            // Only drop a result if it has not been replaced meanwhile.
            if (saved.contains(id) && batch[id] == _pending[id]) {
              _pending.remove(id);
              _saved.add(id);
            } else if (unknown.contains(id)) {
              _pending.remove(id);
              _unknown.add(id);
            }
          }
          ok = true;
        }
      }
    } catch (_) {
      ok = false;
    }
    _setState(
      ok && _pending.isEmpty ? ResultsSyncState.saved : ResultsSyncState.failed,
    );
    if (_again || (ok && _pending.isNotEmpty)) {
      _again = false;
      if (ok) await send();
    }
  }

  void _setState(ResultsSyncState s) {
    _state = s;
    notifyListeners();
  }

  static Set<String> _ids(Object? list) =>
      list is List ? {for (final x in list) '$x'} : <String>{};

  /// The JSON body for [entries].
  static Map<String, Object> bodyFor(Iterable<TallyEntry> entries) => {
    'results': [
      for (final e in entries)
        {
          'id': e.id,
          'game': e.game.jsonValue,
          'phase': e.phase.number,
          'right': e.right,
          if (e.hinted) 'hinted': true,
          'date': SessionTally.dateText(e.checkedAt),
        },
    ],
  };
}
