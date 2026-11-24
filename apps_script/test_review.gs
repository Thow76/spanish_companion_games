// Spanish Games: links the Test Review sheet and the app.
//  - As soon as the "Questions" tab changes (and every hour as a fallback,
//    and from the Spanish Games menu): the tab becomes questions.json on
//    Drive, which the app reads. Run setUpTriggers() once to switch this on.
//    Matching rounds made from the rule bank are checked against the
//    "Rules" tab on the way, and a round that fails is left out.
//  - Results: the app sends each answer here (deployed as a web app) and
//    the script moves the mistake along the stage ladder in Test Review
//    (Stage, Locked Stage, Last Result, Last Practised).
// Lives in the Test Review sheet (Extensions → Apps Script).

const FILE_ID = '1_ooFoNCuUjmMDNXWn8NFjl4GzMjxerPs'; // questions.json in the Spanish Companion folder
const TAB = 'Questions';     // tab ChatGPT fills in
const REVIEW_TAB = 'Sheet1'; // main Test Review tab
const SHEET_ID = '1ukvaMOtiRTQHBrv17SGdqvTARnb_x7mlRaTad1YJDLw'; // the Test Review spreadsheet

// Opened by ID, so the script works whether it was created from the sheet
// (Extensions → Apps Script) or on its own at script.google.com.
function book_() {
  return SpreadsheetApp.openById(SHEET_ID);
}

// ---------- Menu and timer ----------

function onOpen() {
  SpreadsheetApp.getUi().createMenu('Spanish Games')
    .addItem('Update questions.json now', 'exportQuestions')
    .addItem('Move items onto the ladder', 'moveItemsOntoLadder')
    .addToUi();
}

// Run once by hand (replaces the old setUpHourly): exports questions.json
// whenever the spreadsheet changes, plus every hour as a fallback.
function setUpTriggers() {
  ScriptApp.getProjectTriggers()
    .filter(t => ['exportQuestions', 'questionsChanged']
      .indexOf(t.getHandlerFunction()) >= 0)
    .forEach(t => ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger('questionsChanged').forSpreadsheet(SHEET_ID).onChange().create();
  ScriptApp.newTrigger('exportQuestions').timeBased().everyHours(1).create();
  console.log('Triggers set: on change, and hourly.');
}

const SETTLE_MS = 5000; // let a burst of edits finish before reading the tab

// Runs on any change to the spreadsheet. The change event does not say which
// tab changed, so this compares the Questions tab with what was last
// exported and only exports when it differs. Under the script lock, so a
// burst of ChatGPT edits queues up and the later runs find nothing new.
function questionsChanged(e) {
  if (e && e.changeType === 'FORMAT') return;
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(60000)) {
    console.log('Busy; the next change or the hourly run will export.');
    return;
  }
  try {
    Utilities.sleep(SETTLE_MS);
    const sheet = book_().getSheetByName(TAB);
    if (!sheet) return;
    if (fingerprint_(sheet.getDataRange().getValues()) === lastFingerprint_()) {
      console.log('The Questions tab has not changed since the last export.');
      return;
    }
    exportQuestions();
  } finally {
    lock.releaseLock();
  }
}

// ---------- Helpers ----------

function text_(v, tz) {
  if (v instanceof Date) return Utilities.formatDate(v, tz, 'yyyy-MM-dd');
  return String(v == null ? '' : v).trim();
}

// Column numbers (1-based) in the Test Review tab, found by header name.
// "Passed" appears three times, so each one is the column after its
// "... Complete" column. The old Test 1 / Resit / Recall columns are only
// read now (history, and for "Move items onto the ladder"). The script owns
// Stage, Locked Stage, Last Result and Last Practised and adds any of those
// headers that are missing; Rule ID belongs to the ChatGPT games task.
function reviewColumns_(sheet) {
  const head = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0]
    .map(h => String(h).trim().toLowerCase());
  const find = name => head.indexOf(name) + 1; // 0 = missing
  const cols = {
    id: find('item id'),
    test1: find('test 1 complete'),
    needsResit: find('needs resit'),
    resit: find('resit complete'),
    recall: find('recall complete'),
    lastPractised: find('last practised'),
    stage: find('stage'),
    lockedStage: find('locked stage'),
    lastResult: find('last result'),
    ruleId: find('rule id'),
  };
  cols.test1Passed = cols.test1 ? cols.test1 + 1 : 0;
  cols.resitPassed = cols.resit ? cols.resit + 1 : 0;
  cols.recallPassed = cols.recall ? cols.recall + 1 : 0;
  let next = head.length + 1;
  const ensure = (key, title) => {
    if (cols[key]) return;
    cols[key] = next++;
    sheet.getRange(1, cols[key]).setValue(title);
  };
  ensure('lastPractised', 'Last Practised');
  ensure('stage', 'Stage');
  ensure('lockedStage', 'Locked Stage');
  ensure('lastResult', 'Last Result');
  return cols;
}

// ---------- The stage ladder ----------
// Stages are kept as ranks: 1–5, 6 = C (Consolidation), 7 = R (retired),
// 0 = not on the ladder yet.

const CONSOLIDATION = 6;
const RETIRED = 7;

// A Test Review Stage or Locked Stage cell → rank.
function sheetRank_(v) {
  const t = String(v == null ? '' : v).trim().toLowerCase();
  if (/^[1-5](\.0+)?$/.test(t)) return Number(t);
  if (t === 'c' || t === 'consolidation') return CONSOLIDATION;
  if (t === 'r' || t === 'retired') return RETIRED;
  return 0;
}

// A rank → what goes in the cell.
function rankText_(rank) {
  if (rank === CONSOLIDATION) return 'C';
  if (rank === RETIRED) return 'R';
  return rank || '';
}

// The `stage` the app posts (1–5 or "consolidation") → rank (0 if unusable).
function resultRank_(v) {
  const r = sheetRank_(v);
  return r === RETIRED ? 0 : r;
}

// A Questions tab `stage` cell → the value for questions.json, or null.
function exportStage_(v) {
  const r = sheetRank_(v);
  if (r >= 1 && r <= 5) return r;
  if (r === CONSOLIDATION) return 'consolidation';
  return null;
}

// Where a mistake goes after one answer at stage `at` (a rank, 1–6).
// state = {stage, locked} (ranks; locked 0 = none). Returns the new state.
//  - right at N (1–5): Stage N+1 (after 5, C); never moves a mistake back.
//    A lock at or below N+1 is cleared, which covers "right at N−1 while
//    Locked Stage = N → Stage N, lock cleared".
//  - wrong at N (2–5): Stage N−1, Locked Stage N. Wrong at 1: stays at 1,
//    no lock (there is nothing below to drop back to).
//  - consolidation: Stage C, right or wrong; retiring is decided once all
//    the mistake's consolidation questions are passed (see saveResults_).
//  - a retired mistake stays retired.
function nextStage_(state, at, right) {
  const stage = state.stage, locked = state.locked;
  if (stage === RETIRED) return { stage: stage, locked: 0 };
  if (at === CONSOLIDATION) return { stage: CONSOLIDATION, locked: 0 };
  if (right) {
    return {
      stage: Math.max(stage, at + 1),
      locked: locked && locked <= at + 1 ? 0 : locked,
    };
  }
  return at >= 2 ? { stage: at - 1, locked: at } : { stage: 1, locked: 0 };
}

// The stage a result was answered at. The app (from B26) posts `stage`, but
// for a question written before the ladder (no `item` in the file, so the
// app sends item = id) that stage is only guessed from the game, so the
// mistake's own Stage is used instead; if that is blank too, phase 1 counts
// as stage 1 and phase 2 as stage 2 (as "Move items onto the ladder" does).
function answeredRank_(r, current) {
  const ladderQuestion = r.item && String(r.item).trim() !== String(r.id).trim();
  const posted = resultRank_(r.stage);
  if (ladderQuestion && posted) return posted;
  if (current >= 1 && current <= CONSOLIDATION) return current;
  return Number(r.phase) === 2 ? 2 : 1;
}

// One-off (Spanish Games menu): puts every mistake with a blank Stage on the
// ladder. Recall passed → R (already finished); Test 1 or Resit passed (so in
// Recall) → 2; anything else (Test 1 or Resit still to pass) → 1. Mistakes
// that already have a Stage are left alone, so running it twice is safe.
function moveItemsOntoLadder() {
  const book = book_();
  const tz = book.getSpreadsheetTimeZone();
  const text = v => text_(v, tz);
  const sheet = book.getSheetByName(REVIEW_TAB);
  const c = reviewColumns_(sheet);
  if (!c.id) throw new Error('Test Review has no "Item ID" header');
  const values = sheet.getDataRange().getValues();
  const yes = (row, col) => col > 0 && /^yes$/i.test(text(row[col - 1]));
  const counts = { 1: 0, 2: 0, R: 0, kept: 0 };
  const column = [];
  values.slice(1).forEach(row => {
    const before = row[c.stage - 1];
    if (!text(row[c.id - 1]) || sheetRank_(before)) {
      if (text(row[c.id - 1])) counts.kept++;
      column.push([before == null ? '' : before]);
      return;
    }
    let stage;
    if (yes(row, c.recallPassed)) stage = 'R';
    else if (yes(row, c.test1Passed) || yes(row, c.resitPassed)) stage = 2;
    else stage = 1;
    counts[stage]++;
    column.push([stage]);
  });
  if (column.length) sheet.getRange(2, c.stage, column.length, 1).setValues(column);
  SpreadsheetApp.flush();
  const message = 'Moved onto the ladder: ' + counts[1] + ' at stage 1, ' +
    counts[2] + ' at stage 2, ' + counts.R + ' retired (recall already passed). ' +
    counts.kept + ' already had a stage and were left as they were.';
  console.log(message);
  try { SpreadsheetApp.getUi().alert(message); } catch (err) { /* run from the editor */ }
  return counts;
}

// What the Questions tab held at the last export, to skip unchanged tabs.
function fingerprint_(values) {
  const digest = Utilities.computeDigest(Utilities.DigestAlgorithm.MD5,
    JSON.stringify(values), Utilities.Charset.UTF_8);
  return Utilities.base64Encode(digest);
}

function lastFingerprint_() {
  return PropertiesService.getScriptProperties().getProperty('questionsFingerprint');
}

function rememberFingerprint_(values) {
  PropertiesService.getScriptProperties()
    .setProperty('questionsFingerprint', fingerprint_(values));
}

// ---------- Sentence ordering window (B29) ----------

// A Sentence ordering question longer than this many words shuffles only a
// window of this size around the corrected words; the rest stays on screen
// as fixed text (`fixed_start`, `fixed_end`).
const ORDER_WINDOW = 8;

// The words of a sentence, split on white space (as SentenceText.words).
function words_(sentence) {
  return String(sentence || '').trim().split(/\s+/).filter(Boolean);
}

// A word compared without case or edge punctuation, accents kept
// (as SentenceText._key).
function wordKey_(word) {
  return word.toLowerCase().replace(/^[¿¡"«(]+|[.,;:!?"»)]+$/g, '');
}

// For each word of `target`, whether it is not part of the longest run of
// words shared with `other` (the same comparison as SentenceText.diff).
function changedWords_(target, other) {
  const a = target.map(wordKey_);
  const b = other.map(wordKey_);
  const table = [];
  for (let i = 0; i <= a.length; i++) table.push(new Array(b.length + 1).fill(0));
  for (let i = a.length - 1; i >= 0; i--) {
    for (let j = b.length - 1; j >= 0; j--) {
      table[i][j] = a[i] === b[j]
        ? table[i + 1][j + 1] + 1
        : Math.max(table[i + 1][j], table[i][j + 1]);
    }
  }
  const kept = new Array(a.length).fill(false);
  let i = 0;
  let j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] === b[j]) {
      kept[i] = true;
      i++;
      j++;
    } else if (table[i + 1][j] >= table[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return kept.map(k => !k);
}

// Picks the shuffled window for a Sentence ordering question. `prompt` is the
// corrected sentence, `answers` the accepted sentences (the corrected one and
// any alternatives) and `original` Andrew's sentence from the Questions tab's
// `original` column. Returns null when the whole sentence is shuffled (8 words
// or fewer, no original, or nothing changed), else {prompt, answers,
// fixed_start, fixed_end}, where the prompt and each answer are only the
// window. An alternative answer that does not share the fixed start and end
// word for word is dropped. If the changed words span more than 8 words, the
// window is the first 8 of them.
function orderWindow_(prompt, answers, original) {
  const w = words_(prompt);
  if (w.length <= ORDER_WINDOW) return null;
  const orig = words_(original);
  if (!orig.length) return null;
  const changed = changedWords_(w, orig);
  const first = changed.indexOf(true);
  if (first < 0) return null;
  const last = changed.lastIndexOf(true);

  let start;
  const span = last - first + 1;
  if (span >= ORDER_WINDOW) {
    start = first;
  } else {
    const spare = ORDER_WINDOW - span;
    start = first - Math.floor(spare / 2);
  }
  start = Math.max(0, Math.min(start, w.length - ORDER_WINDOW));
  const end = start + ORDER_WINDOW; // first word after the window

  const before = w.slice(0, start);
  const after = w.slice(end);
  const middle = sentence => {
    const s = words_(sentence);
    if (s.length <= before.length + after.length) return null;
    for (let k = 0; k < before.length; k++) if (s[k] !== before[k]) return null;
    for (let k = 0; k < after.length; k++) {
      if (s[s.length - after.length + k] !== after[k]) return null;
    }
    return s.slice(before.length, s.length - after.length).join(' ');
  };

  const window = w.slice(start, end).join(' ');
  const out = [window];
  (answers || []).forEach(a => {
    const m = middle(a);
    if (m && out.indexOf(m) < 0) out.push(m);
  });
  const result = { prompt: window, answers: out };
  if (before.length) result.fixed_start = before.join(' ');
  if (after.length) result.fixed_end = after.join(' ');
  return result;
}

// ---------- Matching rounds and the rule bank (B28) ----------

const RULES_TAB = 'Rules'; // one row per slot: Rule ID, Rule name, Slot,
                           // What the slot needs, Approved starts, Fixed answer

// Compares starts and answers: spaces trimmed and collapsed, case ignored,
// accents kept (as the app's answer checking).
function ruleKey_(s) {
  return String(s == null ? '' : s).trim().replace(/\s+/g, ' ').toLowerCase();
}

// Turns the Rules tab's rows (header first) into
// {ruleId: {name, slots: [{slot, needs, starts: [keys], fixed: key|''}]}}.
// Columns found by header name. Rows without a Rule ID are ignored.
function parseRules_(values) {
  const rules = {};
  if (!values || !values.length) return rules;
  const head = values[0].map(h => ruleKey_(h));
  const col = name => head.indexOf(name);
  const c = {
    id: col('rule id'), name: col('rule name'), slot: col('slot'),
    needs: col('what the slot needs'), starts: col('approved starts'),
    fixed: col('fixed answer'),
  };
  if (c.id < 0 || c.starts < 0) return rules;
  const cell = (row, i) => i < 0 ? '' : String(row[i] == null ? '' : row[i]).trim();
  values.slice(1).forEach(row => {
    const id = cell(row, c.id);
    if (!id) return;
    const rule = rules[id] || (rules[id] = { name: cell(row, c.name), slots: [] });
    rule.slots.push({
      slot: cell(row, c.slot) || String(rule.slots.length + 1),
      needs: cell(row, c.needs),
      starts: cell(row, c.starts).split('|').map(ruleKey_).filter(Boolean),
      fixed: ruleKey_(cell(row, c.fixed)),
    });
  });
  return rules;
}

// Reads the Rules tab; null if the tab is missing.
function readRules_(book) {
  const sheet = book.getSheetByName(RULES_TAB);
  if (!sheet) return null;
  return parseRules_(sheet.getDataRange().getValues());
}

// Checks a Matching round against its rule. `pairs` is [[start, answer], …].
// Returns '' when the round is fine, else why it fails: an unknown rule, a
// pair that is not two parts, a start in no slot's list, two pairs for one
// slot, a slot with no pair, an answer that is not the slot's Fixed answer,
// or two answers the same.
function checkMatchRound_(ruleId, pairs, rules) {
  const rule = rules[ruleId];
  if (!rule) return 'rule "' + ruleId + '" is not in the Rules tab';
  if (!Array.isArray(pairs) || !pairs.length) return 'it has no pairs';
  const used = new Set();
  const answers = new Set();
  for (let i = 0; i < pairs.length; i++) {
    const p = pairs[i];
    if (!Array.isArray(p) || p.length !== 2 || !ruleKey_(p[0]) || !ruleKey_(p[1])) {
      return 'pair ' + (i + 1) + ' is not "start = answer"';
    }
    const start = ruleKey_(p[0]);
    const answer = ruleKey_(p[1]);
    const slots = rule.slots.filter(s => s.starts.indexOf(start) >= 0);
    if (!slots.length) return '"' + p[0] + '" is not an approved start for ' + ruleId;
    const slot = slots.filter(s => !used.has(s))[0];
    if (!slot) return 'two pairs use slot ' + slots[0].slot + ' ("' + p[0] + '")';
    used.add(slot);
    if (slot.fixed && answer !== slot.fixed) {
      return '"' + p[0] + '" should be matched with "' + slot.fixed + '", not "' + p[1] + '"';
    }
    if (answers.has(answer)) return 'the answer "' + p[1] + '" appears twice';
    answers.add(answer);
  }
  const missing = rule.slots.filter(s => !used.has(s));
  if (missing.length) {
    return 'no pair for slot ' + missing.map(s => s.slot).join(', ');
  }
  return '';
}

// ---------- Questions tab → questions.json ----------

function exportQuestions(allowEmpty) {
  const book = book_();
  const tz = book.getSpreadsheetTimeZone();
  const text = v => text_(v, tz);
  const list = s => s ? s.split('|').map(x => x.trim()).filter(Boolean) : [];
  const rules = readRules_(book); // null: no Rules tab, rounds not checked
  let rulesWarned = false;

  // Retired items (Stage R) are left out, even if a row is still there. An
  // item not yet on the ladder (blank Stage) counts as finished once its
  // recall has been passed, as before the ladder.
  const finished = new Set();
  const review = book.getSheetByName(REVIEW_TAB);
  if (review) {
    const c = reviewColumns_(review);
    if (c.id) {
      review.getDataRange().getValues().slice(1).forEach(row => {
        const rank = sheetRank_(row[c.stage - 1]);
        const recallDone = c.recallPassed &&
          /^yes$/i.test(text(row[c.recallPassed - 1]));
        if (rank === RETIRED || (!rank && recallDone)) finished.add(text(row[c.id - 1]));
      });
    }
  }

  const sheet = book.getSheetByName(TAB);
  if (!sheet) throw new Error('No tab called "' + TAB + '"');
  const rows = sheet.getDataRange().getValues();
  const tabValues = rows.slice();
  const head = rows.shift().map(x => text(x).toLowerCase());

  const byId = new Map(); // the newest row for an id wins
  rows.forEach(row => {
    const get = name => {
      const i = head.indexOf(name);
      return i < 0 ? '' : text(row[i]);
    };
    const id = get('id');
    const item = get('item');
    if (!id || finished.has(item || id)) return;

    const game = get('game');
    const q = { id: id };
    // Stage ladder fields (B26 format), each left out when empty.
    if (item) q.item = item;
    const stage = exportStage_(get('stage'));
    if (stage !== null) q.stage = stage;
    const phase = Number(get('phase'));
    if (phase === 1 || phase === 2) q.phase = phase;
    q.game = game;
    const unlocksAfter = get('unlocks_after');
    if (unlocksAfter) q.unlocks_after = unlocksAfter;
    // `rule` is the rule bank ID, only meaningful on a Matching round.
    const rule = get('rule');
    if (rule && game === 'match') q.rule = rule;
    q.type = get('type') || 'grammar';
    q.category = get('category');
    q.prompt = get('prompt');
    q.answers = game === 'match'
      ? list(get('answers')).map(p => p.split('=').map(x => x.trim()))
      : list(get('answers'));
    // Sentence ordering: a long sentence shuffles only a window around the
    // corrected words; the words before and after are shown as fixed text.
    if (game === 'order') {
      const win = orderWindow_(q.prompt, q.answers, get('original'));
      if (win) {
        q.prompt = win.prompt;
        q.answers = win.answers;
        if (win.fixed_start) q.fixed_start = win.fixed_start;
        if (win.fixed_end) q.fixed_end = win.fixed_end;
      }
    }
    const options = list(get('options'));
    if (options.length) q.options = options;
    if (/^(true|yes)$/i.test(get('missing_word'))) q.missing_word = true;
    q.explanation = get('explanation');
    // Optional hints for Repair (and Choose a correction), left out when empty.
    const focus = get('focus');
    if (focus) q.focus = focus;
    const hint = get('hint');
    if (hint) q.hint = hint;
    q.source = get('source');
    q.added = get('added');

    // Matching rounds made from the rule bank are checked against the Rules
    // tab; a round that fails is left out (and an older row for the same id
    // does not come back). A round without a rule ID is kept as before.
    byId.delete(id);
    if (game === 'match' && q.rule) {
      if (!rules) {
        if (!rulesWarned) console.log('No "' + RULES_TAB + '" tab, so Matching rounds were not checked.');
        rulesWarned = true;
      } else {
        const why = checkMatchRound_(q.rule, q.answers, rules);
        if (why) {
          console.log('Left out Matching round ' + id + ': ' + why + '.');
          return;
        }
      }
    }

    byId.set(id, q);
  });

  // An empty tab leaves the current file alone (so a tab ChatGPT has not
  // filled yet never wipes the app), unless results have just emptied it.
  if (byId.size === 0 && allowEmpty !== true) {
    console.log('The Questions tab is empty, so questions.json was left as it is.');
    rememberFingerprint_(tabValues);
    return 0;
  }

  const json = JSON.stringify(Array.from(byId.values()), null, 2);
  const file = DriveApp.getFileById(FILE_ID);
  if (file.getBlob().getDataAsString('UTF-8') !== json) {
    file.setContent(json);
    console.log('Wrote ' + byId.size + ' questions to questions.json.');
  } else {
    console.log('questions.json already has these ' + byId.size + ' questions.');
  }
  rememberFingerprint_(tabValues);
  return byId.size;
}

// ---------- Results from the app ----------

// The app posts {"results": [{"id", "item", "stage", "game", "phase",
// "right", "date", "hinted"?}]} (`item` and `stage` from B26; "right with a
// hint" comes as right: false). Answers {"ok": true, "saved": [ids],
// "unknown": [ids with no row]}.
function doPost(e) {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const body = JSON.parse(e.postData.contents);
    const answer = saveResults_(body.results || []);
    return json_(Object.assign({ ok: true }, answer));
  } catch (err) {
    return json_({ ok: false, error: String(err) });
  } finally {
    lock.releaseLock();
  }
}

// Opening the web app address in a browser just says it is running.
function doGet() {
  return ContentService.createTextOutput('Spanish Games results: running.');
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function saveResults_(results) {
  const book = book_();
  const tz = book.getSpreadsheetTimeZone();
  const text = v => text_(v, tz);
  const sheet = book.getSheetByName(REVIEW_TAB);
  const c = reviewColumns_(sheet);
  if (!c.id) throw new Error('Test Review headers not found');

  const values = sheet.getDataRange().getValues();
  const rowOf = new Map();
  values.forEach((row, i) => {
    if (i > 0 && text(row[c.id - 1])) rowOf.set(text(row[c.id - 1]), i + 1);
  });

  // The mistake's row: by `item`, else by `id`, else by `id` without a
  // ladder suffix (FB-0012-s3 → FB-0012).
  const findRow = r => {
    const keys = [r.item, r.id, String(r.id || '').replace(/-s(c?\d+)$/i, '')]
      .map(k => String(k || '').trim()).filter(Boolean);
    for (const k of keys) if (rowOf.has(k)) return { key: k, row: rowOf.get(k) };
    return null;
  };

  const state = new Map();  // row → {item, stage, locked, result, date}
  const saved = [], unknown = [], passed = new Set();
  const consolidationPassed = new Set(); // items with a consolidation question right
  results.forEach(r => {
    const id = String(r.id || '').trim();
    const date = String(r.date || '').trim() ||
      Utilities.formatDate(new Date(), tz, 'yyyy-MM-dd');
    const found = findRow(r);
    if (!found) { unknown.push(id); return; }
    const row = found.row;
    const now = state.get(row) || {
      item: found.key,
      stage: sheetRank_(values[row - 1][c.stage - 1]),
      locked: sheetRank_(values[row - 1][c.lockedStage - 1]),
    };
    const right = r.right === true || r.right === 'true';
    const at = answeredRank_(r, now.stage);
    const next = nextStage_(now, at, right);
    now.stage = next.stage;
    now.locked = next.locked;
    now.result = right ? 'right' : 'wrong';
    now.date = date;
    state.set(row, now);
    saved.push(id);
    if (right) {
      passed.add(id);
      if (at === CONSOLIDATION) consolidationPassed.add(now.item);
    }
  });

  // A question answered right leaves the Questions tab, so it is not played
  // again before ChatGPT writes the next stage's question. Wrong ones stay.
  // A mistake at C with a consolidation question passed and no consolidation
  // question left in the tab is retired (R), and all its rows go.
  const retired = new Set();
  const tab = book.getSheetByName(TAB);
  if (tab && (passed.size || consolidationPassed.size)) {
    const rows = tab.getDataRange().getValues();
    const head = rows[0].map(h => String(h).trim().toLowerCase());
    const col = name => head.indexOf(name);
    const idCol = col('id'), itemCol = col('item'), stageCol = col('stage'),
      gameCol = col('game');
    if (idCol >= 0) {
      const itemOf = row => (itemCol >= 0 && text(row[itemCol])) || text(row[idCol]);
      const isConsolidation = row => {
        const rank = stageCol >= 0 ? sheetRank_(row[stageCol]) : 0;
        if (rank) return rank === CONSOLIDATION;
        const game = gameCol >= 0 ? text(row[gameCol]) : '';
        return game === 'order' || game === 'match';
      };
      const remaining = rows.slice(1).filter(row => !passed.has(text(row[idCol])));
      consolidationPassed.forEach(item => {
        const left = remaining.some(row => itemOf(row) === item && isConsolidation(row));
        if (!left) retired.add(item);
      });
      for (let i = rows.length - 1; i >= 1; i--) {
        if (passed.has(text(rows[i][idCol])) || retired.has(itemOf(rows[i]))) {
          tab.deleteRow(i + 1);
        }
      }
    }
  }

  state.forEach((now, row) => {
    if (retired.has(now.item) && now.stage === CONSOLIDATION) now.stage = RETIRED;
    sheet.getRange(row, c.stage).setValue(rankText_(now.stage));
    sheet.getRange(row, c.lockedStage).setValue(rankText_(now.locked));
    sheet.getRange(row, c.lastResult).setValue(now.result);
    sheet.getRange(row, c.lastPractised).setValue(now.date);
  });

  SpreadsheetApp.flush();
  if (passed.size) exportQuestions(true);
  return { saved: saved, unknown: unknown };
}
