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
