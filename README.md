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
./deploy.sh
```

The script stops with a message if either value is missing. It runs
`flutter build web --release` with both values as `--dart-define`s, then
`firebase deploy --only hosting`. Never commit the key or the file ID.
After the first deploy, add the hosting address (`https://<project>.web.app/*`)
to the API key's allowed websites in Google Cloud.
