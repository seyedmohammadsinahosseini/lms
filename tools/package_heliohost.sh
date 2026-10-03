#!/usr/bin/env bash
# Builds the exact directory layout expected by a HelioHost Plesk account.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/deploy-heliohost}"
: "${OTMS_API_BASE:?Set OTMS_API_BASE to https://YOUR-SUBDOMAIN.helioho.st/api/v1}"

OTMS_WEBROOT_NAME=httpdocs \
  bash "$ROOT/tools/package_deployment.sh" "$OUT"

cat >"$OUT/HELIOHOST_DEPLOY.txt" <<EOF
OTMS HelioHost layout
=====================

Upload the CONTENTS of each local directory through Plesk File Manager or FTPS:
  httpdocs/  -> /httpdocs/
  config/    -> /config/
  storage/   -> /storage/
  tools/     -> /tools/

Then:
1. Rename /config/otms.env.example to /config/otms.env and fill it in.
2. Keep /config and /storage outside /httpdocs; never move them into webroot.
3. Create an empty MariaDB database in Plesk and import schema.sql with phpMyAdmin.
4. In Plesk, issue a free SSL certificate and force HTTPS after issuance.
5. Test: $OTMS_API_BASE/health.php

No SSH is required. The PHP bootstrap automatically looks for
../config/otms.env relative to /httpdocs.
EOF

echo "HelioHost bundle created at: $OUT"
