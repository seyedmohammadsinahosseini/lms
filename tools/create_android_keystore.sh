#!/usr/bin/env bash
# One-time signing-key creation. Keep the resulting file and passwords backed up.
set -euo pipefail
OUT="${1:-$HOME/lms-release.jks}"
ALIAS="${LMS_KEY_ALIAS:-lms}"
command -v keytool >/dev/null || { echo 'keytool is required (install JDK 17+).' >&2; exit 1; }
[[ ! -e "$OUT" ]] || { echo "Refusing to overwrite $OUT" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
keytool -genkeypair -v -keystore "$OUT" -alias "$ALIAS" \
  -keyalg RSA -keysize 4096 -validity 10000
chmod 600 "$OUT"
echo
printf 'Created %s with alias %s. Back up this file and its passwords now.\n' "$OUT" "$ALIAS"
