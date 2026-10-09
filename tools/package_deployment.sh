#!/usr/bin/env bash
# Creates a same-origin Flutter Web + PHP deployment bundle.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER="${FLUTTER:-flutter}"
OUT="${1:-$ROOT/deploy-package}"
WEBROOT_NAME="${LMS_WEBROOT_NAME:-www}"
: "${LMS_API_BASE:?Set the public HTTPS API URL, e.g. https://demo.example.test/api/v1}"
[[ "$LMS_API_BASE" == https://*/api/v1 ]] || {
  echo 'LMS_API_BASE must be HTTPS and end in /api/v1.' >&2; exit 2;
}
[[ "$WEBROOT_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo 'LMS_WEBROOT_NAME must be a single safe directory name.' >&2; exit 2;
}
WEBROOT="$OUT/$WEBROOT_NAME"

rm -rf "$OUT"
mkdir -p "$WEBROOT/api" "$OUT/config" "$OUT/storage/uploads" "$OUT/tools"
cd "$ROOT/lms_flutter"
"$FLUTTER" pub get
"$FLUTTER" build web --release --no-wasm-dry-run \
  --dart-define="LMS_API_BASE=$LMS_API_BASE" \
  --dart-define=LMS_APP_MODE=portfolio_demo
cp -R build/web/. "$WEBROOT/"
cp -R "$ROOT/backend/api/." "$WEBROOT/api/"
cp "$ROOT/backend/config.php" "$ROOT/backend/cors.php" "$ROOT/backend/helpers.php" \
   "$ROOT/backend/assessment_service.php" "$ROOT/backend/live_service.php" "$WEBROOT/"
cp "$ROOT/backend/.env.example" "$OUT/config/lms.env.example"
cp "$ROOT/backend/schema.sql" "$OUT/schema.sql"
cp "$ROOT/tools/create_teacher_invite.php" "$OUT/tools/"

cat >"$WEBROOT/.htaccess" <<'HTACCESS'
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
1. Copy $WEBROOT_NAME/ to your site's document root.
2. Copy config/ and storage/ to the private parent of the document root.
3. Rename config/lms.env.example to config/lms.env and fill every secret.
4. Import schema.sql into an EMPTY managed MySQL 8 or MariaDB database.
5. Force HTTPS for the site.
6. Open $LMS_API_BASE/health.php, then create an isolated demo from the app.
EOF

echo "Deployment bundle created at: $OUT"
