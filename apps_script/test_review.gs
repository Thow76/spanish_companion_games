// Spanish Games: links the Test Review sheet and the app.
//  - Every hour (and from the Spanish Games menu): the "Questions" tab
//    becomes questions.json on Drive, which the app reads.
//  - Results: the app sends each answer here (deployed as a web app) and
//    the script fills in Test Review.
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
    .addToUi();
}

// Run once by hand: updates the file every hour from then on.
function setUpHourly() {
  ScriptApp.getProjectTriggers()
    .filter(t => t.getHandlerFunction() === 'exportQuestions')
    .forEach(t => ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger('exportQuestions').timeBased().everyHours(1).create();
}

// ---------- Helpers ----------

function text_(v, tz) {
  if (v instanceof Date) return Utilities.formatDate(v, tz, 'yyyy-MM-dd');
  return String(v == null ? '' : v).trim();
}

// Column numbers (1-based) in the Test Review tab, found by header name.
// "Passed" appears three times, so each one is the column after its
// "... Complete" column.
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
  };
  cols.test1Passed = cols.test1 ? cols.test1 + 1 : 0;
  cols.resitPassed = cols.resit ? cols.resit + 1 : 0;
  cols.recallPassed = cols.recall ? cols.recall + 1 : 0;
  if (!cols.lastPractised) {
    cols.lastPractised = head.length + 1;
    sheet.getRange(1, cols.lastPractised).setValue('Last Practised');
  }
  return cols;
}

// ---------- Questions tab → questions.json ----------

function exportQuestions(allowEmpty) {
  const book = book_();
  const tz = book.getSpreadsheetTimeZone();
  const text = v => text_(v, tz);
  const list = s => s ? s.split('|').map(x => x.trim()).filter(Boolean) : [];

  // Items whose recall has been passed are left out, even if a row is still there.
  const finished = new Set();
  const review = book.getSheetByName(REVIEW_TAB);
  if (review) {
    const c = reviewColumns_(review);
    if (c.id && c.recallPassed) {
      review.getDataRange().getValues().slice(1).forEach(row => {
        if (/^yes$/i.test(text(row[c.recallPassed - 1]))) finished.add(text(row[c.id - 1]));
      });
    }
  }

  const sheet = book.getSheetByName(TAB);
  if (!sheet) throw new Error('No tab called "' + TAB + '"');
  const rows = sheet.getDataRange().getValues();
  const head = rows.shift().map(x => text(x).toLowerCase());

  const byId = new Map(); // the newest row for an id wins
  rows.forEach(row => {
    const get = name => {
      const i = head.indexOf(name);
      return i < 0 ? '' : text(row[i]);
    };
    const id = get('id');
    if (!id || finished.has(id)) return;

    const game = get('game');
    const q = { id: id };
    const phase = Number(get('phase'));
    if (phase === 1 || phase === 2) q.phase = phase;
    q.game = game;
    q.type = get('type') || 'grammar';
    q.category = get('category');
    q.prompt = get('prompt');
    q.answers = game === 'match'
      ? list(get('answers')).map(p => p.split('=').map(x => x.trim()))
      : list(get('answers'));
    const options = list(get('options'));
    if (options.length) q.options = options;
    if (/^(true|yes)$/i.test(get('missing_word'))) q.missing_word = true;
    q.explanation = get('explanation');
    q.source = get('source');
    q.added = get('added');

    byId.delete(id);
    byId.set(id, q);
  });

  // An empty tab leaves the current file alone (so a tab ChatGPT has not
  // filled yet never wipes the app), unless results have just emptied it.
  if (byId.size === 0 && allowEmpty !== true) return 0;

  const json = JSON.stringify(Array.from(byId.values()), null, 2);
  const file = DriveApp.getFileById(FILE_ID);
  if (file.getBlob().getDataAsString('UTF-8') !== json) {
    file.setContent(json);
  }
  return byId.size;
}

// ---------- Results from the app ----------

// The app posts {"results": [{"id", "game", "phase", "right", "date"}]}.
// Answers {"ok": true, "saved": [ids], "unknown": [ids with no row]}.
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
  if (!c.id || !c.test1 || !c.needsResit || !c.resit || !c.recall) {
    throw new Error('Test Review headers not found');
  }

  const values = sheet.getDataRange().getValues();
  const rowOf = new Map();
  values.forEach((row, i) => {
    if (i > 0 && text(row[c.id - 1])) rowOf.set(text(row[c.id - 1]), i + 1);
  });

  const saved = [], unknown = [], passed = new Set();
  results.forEach(r => {
    const id = String(r.id || '').trim();
    const date = String(r.date || '').trim() ||
      Utilities.formatDate(new Date(), tz, 'yyyy-MM-dd');
    const row = rowOf.get(id);
    if (!row) { unknown.push(id); return; }
    const yesNo = r.right ? 'Yes' : 'No';
    const cell = col => sheet.getRange(row, col);
    const current = col => text(values[row - 1][col - 1]);

    if (Number(r.phase) === 2) {
      // Recall: the latest attempt wins; an earlier one on another day is
      // kept as a note on its Passed cell.
      const before = current(c.recall);
      if (before && before !== date) {
        const note = cell(c.recallPassed).getNote();
        const line = before + ': ' + current(c.recallPassed);
        cell(c.recallPassed).setNote(note ? note + '\n' + line : line);
      }
      cell(c.recall).setValue(date);
      cell(c.recallPassed).setValue(yesNo);
    } else {
      // Phase 1: the first test, unless it was taken on an earlier day, in
      // which case this is a resit. The same day again replaces that day's result.
      const test1 = current(c.test1);
      if (!test1 || test1 === date) {
        cell(c.test1).setValue(date);
        cell(c.test1Passed).setValue(yesNo);
        cell(c.needsResit).setValue(r.right ? 'No' : 'Yes');
      } else {
        cell(c.resit).setValue(date);
        cell(c.resitPassed).setValue(yesNo);
        cell(c.needsResit).setValue(r.right ? 'No' : 'Yes');
      }
    }
    cell(c.lastPractised).setValue(date);
    saved.push(id);
    if (r.right) passed.add(id);
  });

  // A question answered right leaves the Questions tab, so it is not played
  // again before ChatGPT writes its next step (recall, or nothing). Wrong
  // ones stay.
  if (passed.size) {
    const tab = book.getSheetByName(TAB);
    if (tab) {
      const rows = tab.getDataRange().getValues();
      const idCol = rows[0].map(h => String(h).trim().toLowerCase()).indexOf('id');
      if (idCol >= 0) {
        for (let i = rows.length - 1; i >= 1; i--) {
          if (passed.has(text(rows[i][idCol]))) tab.deleteRow(i + 1);
        }
      }
    }
  }
  SpreadsheetApp.flush();
  if (passed.size) exportQuestions(true);
  return { saved: saved, unknown: unknown };
}
