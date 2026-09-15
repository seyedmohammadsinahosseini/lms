#!/usr/bin/env bash
# End-to-end API regression test for the OTMS backend.
#
# Portable port of backend/smoketest.sh (which hardcodes XAMPP Windows paths).
# It starts its own PHP development server, so it does not need Apache running.
#
# Requirements: php-cli, curl, python3, and a MySQL/MariaDB reachable with the
# credentials in backend/config.php and with backend/schema.sql imported.
#
# Usage:  bash tools/api_test.sh
set -uo pipefail

PORT="${PORT:-8099}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="http://127.0.0.1:$PORT/backend/api"
BODY_FILE="$(mktemp)"
SERVER_LOG="$(mktemp)"
PASS=0
FAIL=0

cleanup() {
  [ -n "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null
  rm -f "$BODY_FILE" "$SERVER_LOG"
}
trap cleanup EXIT

echo "== starting php dev server on 127.0.0.1:$PORT (docroot: $ROOT)"
php -S "127.0.0.1:$PORT" -t "$ROOT" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 60); do
  if curl -s -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; then break; fi
  sleep 0.25
done

# --- helpers ----------------------------------------------------------------
CODE=""
BODY=""

api() { # METHOD PATH [JSON_BODY] [TOKEN]
  local method="$1" path="$2" data="${3:-}" token="${4:-}"
  local args=(-s -o "$BODY_FILE" -w '%{http_code}' -X "$method" "$BASE/$path")
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  if [ -n "$data" ]; then
    args+=(-H 'Content-Type: application/json' -d "$data")
  fi
  CODE="$(curl "${args[@]}")"
  BODY="$(cat "$BODY_FILE")"
}

json() { # EXPR evaluated against the parsed body `d`
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
    PASS=$((PASS + 1))
    printf '  ok    %s\n' "$1"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL  %s\n        expected: %s\n        actual:   %s\n' "$1" "$2" "$3"
  fi
}

section() { printf '\n-- %s\n' "$1"; }

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

# --- auth -------------------------------------------------------------------
section "auth"
api POST login.php '{"email":"teacher@otms.test","password":"password"}'
check "teacher login returns 200" "200" "$CODE"
TT=$(json "d.get('token','')")
check "teacher token issued" "true" "$([ -n "$TT" ] && echo true || echo false)"

api POST login.php '{"email":"teacher@otms.test","password":"wrong"}'
check "wrong password is rejected" "401" "$CODE"

api POST login.php '{"email":"teacher@otms.test","password":"wrong"}'
check "rejection does not leak which field was wrong" "Invalid email or password." "$(json "d.get('error','')")"

api GET me.php '' "$TT"
check "me returns the session user" "teacher@otms.test" "$(json "d.get('user',{}).get('email','')")"

api GET me.php
check "me without a token is unauthorized" "401" "$CODE"

api GET me.php '' "not-a-real-token"
check "me with a bogus token is unauthorized" "401" "$CODE"

api POST login.php '{"email":"student@otms.test","password":"password"}'
ST=$(json "d.get('token','')")
check "student login returns a token" "true" "$([ -n "$ST" ] && echo true || echo false)"

# --- role guards ------------------------------------------------------------
section "role guards"
api GET classes_list.php '' "$ST"
check "student can list classes" "200" "$CODE"

api POST class_create.php '{"name":"Nope","description":"x","color":"#6366F1"}' "$ST"
check "student cannot create a class" "403" "$CODE"

api POST class_create.php '{"name":"Nope","description":"x","color":"#6366F1"}'
check "anonymous cannot create a class" "401" "$CODE"

# --- teacher code + enrollment ---------------------------------------------
section "teacher code and enrollment"
api GET code_get.php '' "$TT"
TEACHER_CODE=$(json "d.get('code','')")
check "teacher has a join code" "true" "$([ -n "$TEACHER_CODE" ] && echo true || echo false)"

api POST code_regenerate.php '' "$TT"
check "code can be regenerated" "200" "$CODE"
TEACHER_CODE=$(json "d.get('code','')")

api POST code_lookup.php "{\"code\":\"$TEACHER_CODE\"}" "$ST"
check "student can look up classes by code" "200" "$CODE"

api POST code_lookup.php '{"code":"ZZZZZZ"}' "$ST"
check "unknown code is rejected" "404" "$CODE"

# --- classes ----------------------------------------------------------------
section "classes"
api POST class_create.php '{"name":"API Test Class","description":"created by api_test.sh","color":"#14B8A6"}' "$TT"
check "teacher creates a class" "201" "$CODE"
CLASS_ID=$(json "int(d.get('id',0))")

api GET "class_students.php?class_id=$CLASS_ID" '' "$TT"
check "teacher sees the roster" "200" "$CODE"

api POST enroll.php "{\"class_id\":$CLASS_ID}" "$ST"
check "student enrolls" "200" "$CODE"

api GET "class_students.php?class_id=$CLASS_ID" '' "$TT"
check "roster now has the student" "1" "$(json "len(d.get('students',[]))")"

api GET "lessons_list.php?class_id=$CLASS_ID" '' "$ST"
check "enrolled student can read lessons" "200" "$CODE"

OTHER_CLASS=$(dbq "SELECT id FROM classes WHERE teacher_id <> 1 LIMIT 1")
if [ -n "$OTHER_CLASS" ]; then
  api GET "lessons_list.php?class_id=$OTHER_CLASS" '' "$ST"
  check "student cannot read an unenrolled class" "403" "$CODE"
  api GET "class_students.php?class_id=$OTHER_CLASS" '' "$TT"
  check "teacher cannot read another teacher's class" "403" "$CODE"
fi

# --- lessons + content ------------------------------------------------------
section "lessons and content"
api POST lesson_create.php "{\"class_id\":$CLASS_ID,\"title\":\"API Test Lesson\"}" "$TT"
check "teacher creates a lesson" "201" "$CODE"
LESSON_ID=$(json "int(d.get('id',0))")
check "first lesson starts at position 0" "0" "$(json "int(d.get('position',-1))")"

api POST lesson_create.php "{\"class_id\":$CLASS_ID,\"title\":\"API Test Lesson 2\"}" "$TT"
check "next lesson is appended" "1" "$(json "int(d.get('position',-1))")"

api POST content_create.php "{\"lesson_id\":$LESSON_ID,\"type\":\"note\",\"title\":\"Note\",\"body\":\"hello\"}" "$TT"
check "teacher adds a note" "201" "$CODE"

api POST content_create.php "{\"lesson_id\":$LESSON_ID,\"type\":\"bogus\",\"title\":\"x\",\"body\":\"y\"}" "$TT"
check "unknown content type is rejected" "400" "$CODE"

api GET "content_list.php?lesson_id=$LESSON_ID" '' "$ST"
check "student reads the content" "1" "$(json "len(d.get('contents',[]))")"

# --- assessments ------------------------------------------------------------
section "assessments"
api POST assessment_create.php "{\"class_id\":$CLASS_ID,\"title\":\"API Quiz\",\"description\":\"d\",\"kind\":\"quiz\",\"duration_min\":10}" "$TT"
check "teacher creates an assessment" "201" "$CODE"
ASM_ID=$(json "int(d.get('id',0))")

api POST question_add.php "{\"assessment_id\":$ASM_ID,\"text\":\"1+1?\",\"type\":\"multiple_choice\",\"points\":2,\"options\":[{\"text\":\"2\",\"is_correct\":true},{\"text\":\"3\",\"is_correct\":false}]}" "$TT"
check "teacher adds a multiple-choice question" "201" "$CODE"

api GET "assessment_get.php?id=$ASM_ID" '' "$ST"
check "student can load the assessment" "200" "$CODE"
check "student payload hides which option is correct" "False" "$(json "any('is_correct' in o for q in d.get('questions',[]) for o in q.get('options',[]))")"

api GET "assessment_get.php?id=$ASM_ID" '' "$TT"
check "teacher payload exposes the answer key" "True" "$(json "any('is_correct' in o for q in d.get('questions',[]) for o in q.get('options',[]))")"

api POST attempt_submit.php "{\"assessment_id\":$ASM_ID,\"answers\":{}}" "$ST"
check "student submits an attempt" "201" "$CODE"

api GET "attempts_list.php?assessment_id=$ASM_ID" '' "$TT"
check "teacher sees the attempt" "1" "$(json "len(d.get('attempts',[]))")"

# --- homework + submissions -------------------------------------------------
section "homework and submissions"
api POST homework_create.php "{\"class_id\":$CLASS_ID,\"title\":\"API Homework\",\"description\":\"do it\"}" "$TT"
check "teacher creates homework" "201" "$CODE"
HW_ID=$(json "int(d.get('id',0))")

api POST submission_submit.php "{\"homework_id\":$HW_ID,\"text\":\"my answer\"}" "$ST"
check "student submits text homework" "201" "$CODE"

api GET "submissions_list.php?homework_id=$HW_ID" '' "$TT"
check "teacher sees the submission" "1" "$(json "len(d.get('submissions',[]))")"

# --- Q&A --------------------------------------------------------------------
section "questions and answers"
api POST qa_create.php "{\"class_id\":$CLASS_ID,\"title\":\"How?\",\"body\":\"please explain\"}" "$ST"
check "student opens a thread" "201" "$CODE"
THREAD_ID=$(json "int(d.get('id',0))")

api GET "qa_list.php?class_id=$CLASS_ID" '' "$TT"
check "teacher sees the thread" "1" "$(json "len(d.get('threads',[]))")"

api POST qa_reply.php "{\"thread_id\":$THREAD_ID,\"body\":\"like this\"}" "$TT"
check "teacher replies" "201" "$CODE"

api GET "qa_thread.php?id=$THREAD_ID" '' "$ST"
check "student sees the reply" "1" "$(json "len(d.get('replies',[]))")"

# --- summary ----------------------------------------------------------------
printf '\n== %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
