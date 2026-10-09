#!/usr/bin/env bash
# Builds a release-signed universal APK without committing signing secrets.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER="${FLUTTER:-flutter}"
: "${LMS_API_BASE:?Set LMS_API_BASE to the production HTTPS API, ending in /api/v1}"
: "${LMS_APPLICATION_ID:?Set a unique Android application id, e.g. io.github.seyedmohammadsinahosseini.lms}"
: "${LMS_KEYSTORE:?Set LMS_KEYSTORE to the absolute path of your .jks file}"
: "${LMS_KEY_ALIAS:?Set LMS_KEY_ALIAS}"
: "${LMS_STORE_PASSWORD:?Set LMS_STORE_PASSWORD}"
: "${LMS_KEY_PASSWORD:?Set LMS_KEY_PASSWORD}"

[[ "$LMS_API_BASE" == https://* ]] || { echo 'LMS_API_BASE must use HTTPS.' >&2; exit 2; }
[[ "$LMS_API_BASE" == */api/v1 ]] || { echo 'LMS_API_BASE must end in /api/v1.' >&2; exit 2; }
[[ "$LMS_APPLICATION_ID" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){2,}$ ]] || {
  echo 'LMS_APPLICATION_ID is not a valid reverse-domain identifier.' >&2; exit 2;
}
[[ -f "$LMS_KEYSTORE" ]] || { echo "Keystore not found: $LMS_KEYSTORE" >&2; exit 2; }

PROPERTIES="$ROOT/lms_flutter/android/key.properties"
cleanup() { rm -f "$PROPERTIES"; }
trap cleanup EXIT
cat >"$PROPERTIES" <<EOF
storeFile=$LMS_KEYSTORE
storePassword=$LMS_STORE_PASSWORD
keyAlias=$LMS_KEY_ALIAS
keyPassword=$LMS_KEY_PASSWORD
EOF
chmod 600 "$PROPERTIES"

cd "$ROOT/lms_flutter"
"$FLUTTER" pub get
"$FLUTTER" analyze
"$FLUTTER" test
LMS_APPLICATION_ID="$LMS_APPLICATION_ID" "$FLUTTER" build apk --release \
  --dart-define="LMS_API_BASE=$LMS_API_BASE" \
  --dart-define=LMS_APP_MODE=production

VERSION="$(awk '/^version:/{print $2}' pubspec.yaml | tr '+' '-')"
OUT_DIR="$ROOT/releases"
OUT="$OUT_DIR/lms-$VERSION-universal.apk"
mkdir -p "$OUT_DIR"
cp build/app/outputs/flutter-apk/app-release.apk "$OUT"
sha256sum "$OUT" | tee "$OUT.sha256"
echo "Signed APK: $OUT"
