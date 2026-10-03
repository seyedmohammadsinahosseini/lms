#!/usr/bin/env bash
# Builds the directory layout expected by a Serv00 PHP website.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/deploy-serv00}"
: "${OTMS_API_BASE:?Set OTMS_API_BASE to https://LOGIN.serv00.net/api/v1}"
: "${OTMS_SERV00_LOGIN:?Set OTMS_SERV00_LOGIN to the login from the activation email}"
: "${OTMS_SERV00_SERVER:?Set OTMS_SERV00_SERVER to the assigned host, e.g. s12.serv00.com}"
: "${OTMS_SERV00_DOMAIN:?Set OTMS_SERV00_DOMAIN to the final hostname, e.g. LOGIN.serv00.net}"

LOGIN="${OTMS_SERV00_LOGIN,,}"
SERVER="${OTMS_SERV00_SERVER,,}"
DOMAIN="${OTMS_SERV00_DOMAIN,,}"

[[ "$LOGIN" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || {
  echo 'OTMS_SERV00_LOGIN contains unsupported characters.' >&2; exit 2;
}
[[ "$SERVER" =~ ^s([0-9]+)\.serv00\.com$ ]] || {
  echo 'OTMS_SERV00_SERVER must look like s12.serv00.com.' >&2; exit 2;
}
SERVER_NUMBER="${BASH_REMATCH[1]}"
[[ "$DOMAIN" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]] || {
  echo 'OTMS_SERV00_DOMAIN must be a hostname without scheme or path.' >&2; exit 2;
}
EXPECTED_API_BASE="https://$DOMAIN/api/v1"
[[ "$OTMS_API_BASE" == "$EXPECTED_API_BASE" ]] || {
  echo "OTMS_API_BASE must exactly equal $EXPECTED_API_BASE." >&2; exit 2;
}

OTMS_WEBROOT_NAME=public_html \
  bash "$ROOT/tools/package_deployment.sh" "$OUT"

DOMAIN_ROOT="/usr/home/$LOGIN/domains/$DOMAIN"
DB_HOST="mysql$SERVER_NUMBER.serv00.com"
mkdir -p "$OUT/storage/tmp"

python3 - "$OUT/config/otms.env.example" "$DOMAIN_ROOT" "$DB_HOST" "$DOMAIN" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
domain_root, db_host, domain = sys.argv[2:]
text = path.read_text()
replacements = {
    'YOUR_DATABASE_HOST': db_host,
    'https://YOUR_PUBLIC_DOMAIN': f'https://{domain}',
    '/absolute/private/path/storage/uploads': f'{domain_root}/storage/uploads',
    '/absolute/private/path/config/jaas-private-key.pem': f'{domain_root}/config/jaas-private-key.pem',
}
for old, new in replacements.items():
    text = text.replace(old, new)
path.write_text(text)
PY

cat >"$OUT/.user.ini" <<EOF
; Serv00 per-domain PHP settings. This file belongs beside public_html.
display_errors = Off
log_errors = On
error_log = $DOMAIN_ROOT/storage/php-error.log
upload_tmp_dir = $DOMAIN_ROOT/storage/tmp
upload_max_filesize = 9M
post_max_size = 10M
memory_limit = 256M
max_execution_time = 180
EOF

TMP_HTACCESS="$OUT/public_html/.htaccess.tmp"
{
  echo 'AddType application/x-httpd-php83 .php'
  cat "$OUT/public_html/.htaccess"
} >"$TMP_HTACCESS"
mv "$TMP_HTACCESS" "$OUT/public_html/.htaccess"

cat >"$OUT/SERV00_DEPLOY.txt" <<EOF
OTMS Serv00 layout
==================

Account values used for this package:
  Login:       $LOGIN
  Server:      $SERVER
  Domain:      $DOMAIN
  DB host:     $DB_HOST
  Domain root: $DOMAIN_ROOT

Upload the CONTENTS of this package over SFTP/SSH to:
  $DOMAIN_ROOT/

The resulting server layout must contain:
  $DOMAIN_ROOT/public_html/   (Flutter Web and PHP API)
  $DOMAIN_ROOT/config/        (private environment and JaaS key)
  $DOMAIN_ROOT/storage/       (private uploads, temp files and logs)
  $DOMAIN_ROOT/tools/         (private CLI tools)
  $DOMAIN_ROOT/.user.ini
  $DOMAIN_ROOT/schema.sql

Then:
1. Rename config/otms.env.example to config/otms.env and fill the database
   name, user, password and every remaining placeholder. Never send passwords.
2. In DevilWEB, create an empty MySQL database/user. The host is $DB_HOST.
3. Import schema.sql with phpMyAdmin or the mysql client over SSH.
4. Keep config and storage outside public_html. Set the site's Open Basedir to
   $DOMAIN_ROOT:/tmp if the panel does not already allow the domain root.
5. Generate a free Let's Encrypt certificate, then enable Force SSL.
6. Keep Serv00 PoW/browser challenges OFF so native Android can call the API.
7. Test: $OTMS_API_BASE/health.php

Recommended permissions over SSH:
  chmod 700 '$DOMAIN_ROOT/config' '$DOMAIN_ROOT/storage' '$DOMAIN_ROOT/tools'
  chmod 600 '$DOMAIN_ROOT/config/otms.env'

The PHP bootstrap automatically reads ../config/otms.env relative to
public_html. The real env, uploads, logs, schema and CLI tools remain private.
EOF

echo "Serv00 bundle created at: $OUT"
