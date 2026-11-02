#!/usr/bin/env bash
# Build the web app and deploy it to Firebase Hosting.
#
# Usage (from the repo root):
#   export DRIVE_API_KEY=<key>
#   export DRIVE_FILE_ID=<file id>
#   ./deploy.sh
#
# The key and file ID are passed to the build with --dart-define and are
# never written to the repo. They end up in the built JavaScript, which is
# why the key is restricted to the Drive API and to the allowed websites.
# Needs `flutter` and `firebase` on the PATH and a `firebase login`.

set -euo pipefail

cd "$(dirname "$0")"

missing=()
[[ -n "${DRIVE_API_KEY:-}" ]] || missing+=("DRIVE_API_KEY")
[[ -n "${DRIVE_FILE_ID:-}" ]] || missing+=("DRIVE_FILE_ID")
if (( ${#missing[@]} > 0 )); then
  echo "Stopped: ${missing[*]} not set." >&2
  echo "Set them first, for example:" >&2
  echo "  export DRIVE_API_KEY=<key>" >&2
  echo "  export DRIVE_FILE_ID=<file id>" >&2
  echo "then run ./deploy.sh again. Nothing was built or deployed." >&2
  exit 1
fi

for tool in flutter firebase; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Stopped: '$tool' is not on the PATH. Nothing was deployed." >&2
    exit 1
  fi
done

echo "Building the web app (release)..."
flutter build web --release \
  --dart-define="DRIVE_API_KEY=${DRIVE_API_KEY}" \
  --dart-define="DRIVE_FILE_ID=${DRIVE_FILE_ID}"

echo "Deploying build/web to Firebase Hosting..."
firebase deploy --only hosting

echo
echo "Done. If the site says the website is not allowed to use the key,"
echo "add the hosting address (e.g. https://<project>.web.app/*) to the"
echo "API key's website restrictions in Google Cloud."
