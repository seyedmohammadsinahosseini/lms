#!/usr/bin/env bash
# Security regression tests: authorization, private uploads, CSRF and CORS.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8098}"
BASE="http://127.0.0.1:${PORT}/api/v1"
WORK="$(mktemp -d)"
STORAGE="$WORK/private-storage"
BODY_FILE="$WORK/body"
COOKIE_JAR="$WORK/cookies"
SERVER_LOG="$WORK/server.log"
PASS=0 FAIL=0 SERVER_PID=""
cleanup() {
  if [[ -n "$SERVER_PID" ]]; then kill "$SERVER_PID" 2>/dev/null || true; fi
  rm -rf "$WORK"
}
trap cleanup EXIT

export LMS_APP_ENV=local
export LMS_ALLOW_TEACHER_REGISTRATION=true
export LMS_DEMO_MODE=false
export LMS_APP_KEY='security-test-key-that-is-not-used-in-production'
export LMS_STORAGE_PATH="$STORAGE"
export LMS_ALLOWED_ORIGINS='https://portfolio.example.test'
export LMS_PUBLIC_BASE_URL="http://127.0.0.1:${PORT}"
php -d upload_max_filesize=16M -d post_max_size=18M -S "127.0.0.1:${PORT}" -t "$ROOT/backend" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 80); do curl -fsS "$BASE/health.php" >/dev/null 2>&1 && break; sleep .2; done
curl -fsS "$BASE/health.php" >/dev/null || { cat "$SERVER_LOG" >&2; exit 1; }

CODE="" BODY=""
request() {
  local method="$1" path="$2" data="${3:-}" token="${4:-}"
  local args=(-sS -o "$BODY_FILE" -w '%{http_code}' -X "$method" "$BASE/$path")
  [[ -n "$token" ]] && args+=(-H "Authorization: Bearer $token")
  [[ -n "$data" ]] && args+=(-H 'Content-Type: application/json' --data "$data")
  CODE="$(curl "${args[@]}")"; BODY="$(cat "$BODY_FILE")"
}
post() { request POST "$1" "$2" "${3:-}"; }
get() { request GET "$1" "" "${2:-}"; }
upload() { # endpoint token path field=value...
  local endpoint="$1" token="$2" file="$3"; shift 3
  local args=(-sS -o "$BODY_FILE" -w '%{http_code}' -X POST "$BASE/$endpoint" -H "Authorization: Bearer $token" -F "file=@$file")
  local field; for field in "$@"; do args+=(-F "$field"); done
  CODE="$(curl "${args[@]}")"; BODY="$(cat "$BODY_FILE")"
}
ok() { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n       response(%s): %s\n' "$1" "$CODE" "$BODY"; }
expect_code() {
  if [[ "$CODE" == "$2" ]]; then ok "$1"; else bad "$1 (expected HTTP $2)"; fi
}
expect_jq() {
  if jq -e "$2" >/dev/null 2>&1 <<<"$BODY"; then ok "$1"; else bad "$1 (jq: $2)"; fi
}
section() { printf '\n-- %s --\n' "$1"; }

STAMP="$(date +%s)-$$"; PASSWORD='correct horse battery staple'
register() {
  local name="$1" email="$2" role="$3"
  post register.php "$(jq -nc --arg n "$name" --arg e "$email" --arg p "$PASSWORD" --arg r "$role" '{full_name:$n,email:$e,password:$p,role:$r}')"
  jq -r '.token' <<<"$BODY"
}
TT="$(register Teacher "security-teacher-$STAMP@example.test" teacher)"
ST="$(register Student "security-student-$STAMP@example.test" student)"
OT="$(register Outsider "security-outsider-$STAMP@example.test" student)"
post class_create.php '{"name":"Security class","description":"private","color":"#2563EB"}' "$TT"; CLASS_ID="$(jq -r '.id' <<<"$BODY")"
request GET code_get.php '' "$TT"; TCODE="$(jq -r '.code' <<<"$BODY")"
post code_lookup.php "$(jq -nc --arg c "$TCODE" '{code:$c}')" "$ST"; GRANT="$(jq -r '.join_grant' <<<"$BODY")"
post enroll.php "$(jq -nc --argjson c "$CLASS_ID" --arg g "$GRANT" '{class_id:$c,join_grant:$g}')" "$ST"
post homework_create.php "$(jq -nc --argjson c "$CLASS_ID" '{class_id:$c,title:"Private upload homework",allow_resubmit:true}')" "$TT"; HW_ID="$(jq -r '.id' <<<"$BODY")"
post lesson_create.php "$(jq -nc --argjson c "$CLASS_ID" '{class_id:$c,title:"Private files"}')" "$TT"; LESSON_ID="$(jq -r '.id' <<<"$BODY")"

printf '<?php echo "PWNED"; ?>' >"$WORK/evil.php"
printf '<script>alert(document.cookie)</script>' >"$WORK/active.html"
printf 'not really a pdf' >"$WORK/spoofed.pdf"
printf '%%PDF-1.4\n1 0 obj\n<<>>\nendobj\n%%%%EOF\n' >"$WORK/valid.pdf"
dd if=/dev/zero of="$WORK/huge.pdf" bs=1M count=9 status=none

section upload-validation
upload submission_submit.php "$ST" "$WORK/evil.php" "homework_id=$HW_ID"
expect_code 'executable extension rejected' 415
upload submission_submit.php "$ST" "$WORK/active.html" "homework_id=$HW_ID"
expect_code 'active HTML rejected' 415
upload submission_submit.php "$ST" "$WORK/spoofed.pdf" "homework_id=$HW_ID"
expect_code 'MIME/extension mismatch rejected' 415
upload submission_submit.php "$ST" "$WORK/huge.pdf" "homework_id=$HW_ID"
expect_code 'file over 8 MB rejected' 413
upload submission_submit.php "$ST" "$WORK/valid.pdf" "homework_id=$HW_ID" 'text=private answer'
expect_code 'legitimate PDF accepted' 201
if [[ "$(find "$STORAGE" -type f | wc -l)" == 1 ]]; then
  ok 'upload stored outside document root'
else
  bad 'upload stored outside document root'
fi
PUBLIC_UPLOAD_COUNT="$(find "$ROOT/backend/uploads" -type f ! -name '.gitignore' ! -name '.htaccess' 2>/dev/null | wc -l)"
if [[ "$PUBLIC_UPLOAD_COUNT" == 0 ]]; then
  ok 'no files are written to the legacy public upload directory'
else
  bad 'no files are written to the legacy public upload directory'
fi

section authorized-downloads
get "submissions_list.php?homework_id=$HW_ID" "$TT"
DOWNLOAD_PATH="$(jq -r '.submissions[0].file_path' <<<"$BODY")"
FILE_ID="$(sed -n 's/.*[?&]id=\([0-9]*\).*/\1/p' <<<"$DOWNLOAD_PATH")"
CODE="$(curl -sS -o "$WORK/downloaded.pdf" -w '%{http_code}' "$BASE/$DOWNLOAD_PATH")"
expect_code 'short-lived signed URL downloads without exposing storage path' 200
if cmp -s "$WORK/valid.pdf" "$WORK/downloaded.pdf"; then
  ok 'download bytes match original'
else
  bad 'download bytes match original'
fi
CODE="$(curl -sS -o "$BODY_FILE" -w '%{http_code}' "$BASE/file_download.php?id=$FILE_ID")"; BODY="$(cat "$BODY_FILE")"
expect_code 'bare file id requires authentication' 401
CODE="$(curl -sS -o "$BODY_FILE" -w '%{http_code}' -H "Authorization: Bearer $OT" "$BASE/file_download.php?id=$FILE_ID")"; BODY="$(cat "$BODY_FILE")"
expect_code 'unenrolled student cannot download another submission' 403
CODE="$(curl -sS -o "$BODY_FILE" -w '%{http_code}' -H "Authorization: Bearer $TT" "$BASE/file_download.php?id=$FILE_ID")"; BODY="$(cat "$BODY_FILE")"
expect_code 'owning teacher can download student submission' 200
# A regular expression is clearer than nested shell substitutions here.
# shellcheck disable=SC2001
TAMPERED="$(sed 's/sig=[a-f0-9]*/sig=deadbeef/' <<<"$DOWNLOAD_PATH")"
CODE="$(curl -sS -o "$BODY_FILE" -w '%{http_code}' "$BASE/$TAMPERED")"; BODY="$(cat "$BODY_FILE")"
expect_code 'tampered signed URL is rejected' 401

section class-material-authorization
upload content_create.php "$TT" "$WORK/valid.pdf" "lesson_id=$LESSON_ID" 'type=booklet' 'title=Teacher file'
expect_code 'teacher uploads private class material' 201
get "content_list.php?lesson_id=$LESSON_ID" "$ST"; MATERIAL_PATH="$(jq -r '.contents[0].file_path' <<<"$BODY")"
CODE="$(curl -sS -o "$BODY_FILE" -w '%{http_code}' "$BASE/$MATERIAL_PATH")"; BODY="$(cat "$BODY_FILE")"
expect_code 'enrolled student can use signed class-material URL' 200
MATERIAL_ID="$(sed -n 's/.*[?&]id=\([0-9]*\).*/\1/p' <<<"$MATERIAL_PATH")"
CODE="$(curl -sS -o "$BODY_FILE" -w '%{http_code}' -H "Authorization: Bearer $OT" "$BASE/file_download.php?id=$MATERIAL_ID")"; BODY="$(cat "$BODY_FILE")"
expect_code 'unenrolled student cannot fetch class material by id' 403

section csrf-and-cors
WEB_EMAIL="security-teacher-$STAMP@example.test"
LOGIN_JSON="$(jq -nc --arg e "$WEB_EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
CODE="$(curl -sS -o "$BODY_FILE" -w '%{http_code}' -c "$COOKIE_JAR" -H 'X-LMS-Client: web' -H 'Content-Type: application/json' --data "$LOGIN_JSON" "$BASE/login.php")"; BODY="$(cat "$BODY_FILE")"
expect_code 'web login receives cookie session' 200
CSRF="$(jq -r '.csrf_token' <<<"$BODY")"
CODE="$(curl -sS -o "$BODY_FILE" -w '%{http_code}' -b "$COOKIE_JAR" -H 'X-LMS-Client: web' -H 'Content-Type: application/json' --data '{"full_name":"Blocked CSRF"}' "$BASE/profile_update.php")"; BODY="$(cat "$BODY_FILE")"
expect_code 'cookie mutation without CSRF token is rejected' 403
expect_jq 'CSRF error has fixed code' '.error.code == "CSRF_FAILED"'
CODE="$(curl -sS -o "$BODY_FILE" -w '%{http_code}' -b "$COOKIE_JAR" -H 'X-LMS-Client: web' -H "X-CSRF-Token: $CSRF" -H 'Content-Type: application/json' --data '{"full_name":"CSRF Protected"}' "$BASE/profile_update.php")"; BODY="$(cat "$BODY_FILE")"
expect_code 'valid CSRF token permits cookie mutation' 200
acao() { curl -sS -o /dev/null -D - -H "Origin: $1" "$BASE/health.php" | tr -d '\r' | awk 'tolower($1)=="access-control-allow-origin:"{print $2}'; }
if [[ "$(acao https://portfolio.example.test)" == 'https://portfolio.example.test' ]]; then
  ok 'configured CORS origin allowed'
else
  bad 'configured CORS origin allowed'
fi
if [[ -z "$(acao https://evil.example.test)" ]]; then
  ok 'unconfigured CORS origin blocked'
else
  bad 'unconfigured CORS origin blocked'
fi

printf '\n== %d passed, %d failed ==\n' "$PASS" "$FAIL"
if (( FAIL > 0 )); then tail -n 100 "$SERVER_LOG" >&2; exit 1; fi
