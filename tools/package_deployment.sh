#!/usr/bin/env bash
# Creates an Alwaysdata-compatible same-origin deployment bundle.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER="${FLUTTER:-flutter}"
OUT="${1:-$ROOT/deploy-package}"
: "${OTMS_API_BASE:?Set the public HTTPS API URL, e.g. https://account.alwaysdata.net/api/v1}"
[[ "$OTMS_API_BASE" == https://*/api/v1 ]] || {
  echo 'OTMS_API_BASE must be HTTPS and end in /api/v1.' >&2; exit 2;
}

rm -rf "$OUT"
mkdir -p "$OUT/www/api" "$OUT/config" "$OUT/storage/uploads" "$OUT/tools"
cd "$ROOT/otms_flutter"
"$FLUTTER" pub get
"$FLUTTER" build web --release --no-wasm-dry-run \
  --dart-define="OTMS_API_BASE=$OTMS_API_BASE" \
  --dart-define=OTMS_APP_MODE=portfolio_demo
cp -R build/web/. "$OUT/www/"
cp -R "$ROOT/backend/api/." "$OUT/www/api/"
cp "$ROOT/backend/config.php" "$ROOT/backend/cors.php" "$ROOT/backend/helpers.php" \
   "$ROOT/backend/assessment_service.php" "$ROOT/backend/live_service.php" "$OUT/www/"
cp "$ROOT/backend/.env.example" "$OUT/config/otms.env.example"
cp "$ROOT/backend/schema.sql" "$OUT/schema.sql"
cp "$ROOT/tools/create_teacher_invite.php" "$OUT/tools/"

cat >"$OUT/www/.htaccess" <<'HTACCESS'
Options -Indexes
RewriteEngine On

# Internal bootstrap files are included by API endpoints but never requested.
<FilesMatch "^(config|cors|helpers|assessment_service|live_service)\.php$">
  Require all denied
</FilesMatch>

# Existing files (including /api/v1/*.php) are served normally.
RewriteCond %{REQUEST_FILENAME} -f [OR]
RewriteCond %{REQUEST_FILENAME} -d
RewriteRule ^ - [L]

# Flutter web uses client-side routing.
RewriteRule ^ index.html [L]
HTACCESS
cat >"$OUT/storage/.htaccess" <<'HTACCESS'
Require all denied
HTACCESS
cat >"$OUT/DEPLOY.txt" <<EOF
1. Copy www/ to your site's document root.
2. Copy config/ and storage/ one directory above the document root.
3. Rename config/otms.env.example to config/otms.env and fill every secret.
4. Import schema.sql into an EMPTY managed MariaDB database.
5. Set the site's document root to the copied www directory and force HTTPS.
6. Open $OTMS_API_BASE/health.php, then create an isolated demo from the app.
EOF

echo "Deployment bundle created at: $OUT"
