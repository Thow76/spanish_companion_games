# spanish_companion_games

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Deploying to Firebase Hosting

`firebase.json` serves `build/web` (project in `.firebaserc`). To build and
deploy, from the repo root, after `firebase login`:

```sh
export DRIVE_API_KEY=<key>
export DRIVE_FILE_ID=<file id>
export RESULTS_URL=<web app /exec address>   # optional
./deploy.sh
```

The script stops with a message if either value is missing. It runs
`flutter build web --release` with both values as `--dart-define`s, then
`firebase deploy --only hosting`. Never commit the key or the file ID.
After the first deploy, add the hosting address (`https://<project>.web.app/*`)
to the API key's allowed websites in Google Cloud.

## Sending results to Test Review

When the app is run or built with `RESULTS_URL` (the `/exec` address of the
Test Review sheet's Apps Script, deployed as a web app), every checked
question is sent to it and the script fills in Test Review. For local runs,
add `"RESULTS_URL": "…"` to `drive.json` and run
`flutter run -d chrome --web-port 5000 --dart-define-from-file=drive.json`.
Without it, "Copy results" is the only way to record results.

## Apps Script (Test Review sheet)

`apps_script/test_review.gs` lives in the Test Review sheet (Extensions →
Apps Script). It turns the Questions tab into `questions.json` on Drive and
saves the results the app sends.

`questions.json` is written as soon as the Questions tab changes, with an
hourly run as a fallback and "Spanish Games → Update questions.json now" in
the sheet's menu. To switch this on, paste the script in, save, choose
`setUpTriggers` in the function list and press Run once (approve the
permissions if asked). It replaces the old `setUpHourly` triggers. Changes to
other tabs or to formatting do not export; the script waits a few seconds
after a change so a burst of edits gives one export. Each run is listed under
Executions in the Apps Script editor.

The Questions tab may have two optional columns headed `focus` and `hint`
(found by header name, like the others, in any position). `focus` is a short
line naming the language point, shown above a Repair question; `hint` is
shown after a wrong first try. Both must never give the answer. They are
copied into `questions.json` only when filled in; without them the app falls
back to the question's category. After changing the script, paste it into the
sheet again and save; no trigger set-up is needed.

### Stage ladder (from B27)

Each mistake in the Test Review tab sits at one stage: 1–5, then C
(Consolidation), then R (retired). The script owns four columns, found by
header name and added at the end if missing: **Stage**, **Locked Stage**,
**Last Result** (right or wrong) and **Last Practised**. **Rule ID** belongs
to the ChatGPT games task; the script only reads it. The old Test 1 / Resit /
Recall columns are kept as history and no longer written.

For each result the app sends (`item` and `stage`, from B26):

- right at stage N → Stage N+1 (after 5, C); a right answer never moves a
  mistake back, and a Locked Stage at or below the new stage is cleared (so
  passing N−1 while N is locked brings the mistake back to N);
- wrong at N → Stage N−1 and Locked Stage N (wrong at 1 stays at 1);
- consolidation → Stage C; once a consolidation question is passed and none
  of the mistake's consolidation questions is left in the Questions tab, the
  mistake is retired (R) and all its rows leave the Questions tab.

A question answered right leaves the Questions tab, as before. For a
question written before the ladder (no `item` column), the app's stage is
only a guess from the game, so the script uses the mistake's own Stage.

The Questions tab may have the columns `item`, `stage` (1–5, or C /
consolidation), `unlocks_after` and `rule` (Matching rows only); each is
copied into `questions.json` when filled in. Retired mistakes are left out.

To switch over: paste the script into the sheet and save, then run
"Spanish Games → Move items onto the ladder" once. It gives every mistake
with a blank Stage one: recall already passed → R, in Recall (Test 1 or
Resit passed) → 2, otherwise → 1. Mistakes that already have a Stage are
left alone, so it is safe to run again.
