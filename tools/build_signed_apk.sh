#!/usr/bin/env bash
# Builds a release-signed universal APK without committing signing secrets.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER="${FLUTTER:-flutter}"
: "${OTMS_API_BASE:?Set OTMS_API_BASE to the production HTTPS API, ending in /api/v1}"
: "${OTMS_APPLICATION_ID:?Set a unique Android application id, e.g. io.github.yourname.otms}"
: "${OTMS_KEYSTORE:?Set OTMS_KEYSTORE to the absolute path of your .jks file}"
: "${OTMS_KEY_ALIAS:?Set OTMS_KEY_ALIAS}"
: "${OTMS_STORE_PASSWORD:?Set OTMS_STORE_PASSWORD}"
: "${OTMS_KEY_PASSWORD:?Set OTMS_KEY_PASSWORD}"

[[ "$OTMS_API_BASE" == https://* ]] || { echo 'OTMS_API_BASE must use HTTPS.' >&2; exit 2; }
[[ "$OTMS_API_BASE" == */api/v1 ]] || { echo 'OTMS_API_BASE must end in /api/v1.' >&2; exit 2; }
[[ "$OTMS_APPLICATION_ID" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){2,}$ ]] || {
  echo 'OTMS_APPLICATION_ID is not a valid reverse-domain identifier.' >&2; exit 2;
}
[[ -f "$OTMS_KEYSTORE" ]] || { echo "Keystore not found: $OTMS_KEYSTORE" >&2; exit 2; }

PROPERTIES="$ROOT/otms_flutter/android/key.properties"
cleanup() { rm -f "$PROPERTIES"; }
trap cleanup EXIT
cat >"$PROPERTIES" <<EOF
storeFile=$OTMS_KEYSTORE
storePassword=$OTMS_STORE_PASSWORD
keyAlias=$OTMS_KEY_ALIAS
keyPassword=$OTMS_KEY_PASSWORD
EOF
chmod 600 "$PROPERTIES"

cd "$ROOT/otms_flutter"
"$FLUTTER" pub get
"$FLUTTER" analyze
"$FLUTTER" test
OTMS_APPLICATION_ID="$OTMS_APPLICATION_ID" "$FLUTTER" build apk --release \
  --dart-define="OTMS_API_BASE=$OTMS_API_BASE" \
  --dart-define=OTMS_APP_MODE=production

VERSION="$(awk '/^version:/{print $2}' pubspec.yaml | tr '+' '-')"
OUT_DIR="$ROOT/releases"
OUT="$OUT_DIR/otms-$VERSION-universal.apk"
mkdir -p "$OUT_DIR"
cp build/app/outputs/flutter-apk/app-release.apk "$OUT"
sha256sum "$OUT" | tee "$OUT.sha256"
echo "Signed APK: $OUT"
