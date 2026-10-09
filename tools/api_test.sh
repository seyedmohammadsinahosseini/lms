#!/usr/bin/env bash
# LMS 2.0 end-to-end API regression suite.
# Requires a fresh/imported schema and LMS_DB_* credentials in the environment.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8099}"
BASE="http://127.0.0.1:${PORT}/api/v1"
BODY_FILE="$(mktemp)"
SERVER_LOG="$(mktemp)"
PASS=0
FAIL=0
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]]; then kill "$SERVER_PID" 2>/dev/null || true; fi
  rm -f "$BODY_FILE" "$SERVER_LOG"
}
trap cleanup EXIT

export LMS_APP_ENV="${LMS_APP_ENV:-local}"
export LMS_ALLOW_TEACHER_REGISTRATION=true
export LMS_DEMO_MODE=true
export LMS_PUBLIC_BASE_URL="http://127.0.0.1:${PORT}"
php -S "127.0.0.1:${PORT}" -t "$ROOT/backend" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 80); do
  curl -fsS "$BASE/health.php" >/dev/null 2>&1 && break
  sleep .2
done
curl -fsS "$BASE/health.php" >/dev/null || {
  cat "$SERVER_LOG" >&2
  exit 1
}

CODE="" BODY=""
request() { # METHOD PATH [JSON] [TOKEN]
  local method="$1" path="$2" data="${3:-}" token="${4:-}"
  local args=(-sS -o "$BODY_FILE" -w '%{http_code}' -X "$method" "$BASE/$path")
  [[ -n "$token" ]] && args+=(-H "Authorization: Bearer $token")
  [[ -n "$data" ]] && args+=(-H 'Content-Type: application/json' --data "$data")
  CODE="$(curl "${args[@]}")"
  BODY="$(cat "$BODY_FILE")"
}
get() { request GET "$1" "" "${2:-}"; }
post() {
  local data="${2:-}"
  [[ -n "$data" ]] || data='{}'
  request POST "$1" "$data" "${3:-}"
}
value() { jq -r "$1" <<<"$BODY"; }

ok() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail_check() {
  FAIL=$((FAIL + 1))
  printf '  FAIL %s\n       response(%s): %s\n' "$1" "$CODE" "$BODY"
}
expect_code() {
  local name="$1" expected="$2"
  if [[ "$CODE" == "$expected" ]]; then
    ok "$name"
  else
    fail_check "$name (expected HTTP $expected)"
  fi
}
expect_jq() {
  local name="$1" expr="$2"
  if jq -e "$expr" >/dev/null 2>&1 <<<"$BODY"; then
    ok "$name"
  else
    fail_check "$name (jq: $expr)"
  fi
}
section() { printf '\n-- %s --\n' "$1"; }

STAMP="$(date +%s)-$$"
TEACHER_EMAIL="teacher-${STAMP}@example.test"
STUDENT_EMAIL="student-${STAMP}@example.test"
PASSWORD='correct horse battery staple'

section auth
post register.php "$(jq -nc --arg n 'API Teacher' --arg e "$TEACHER_EMAIL" --arg p "$PASSWORD" '{full_name:$n,email:$e,password:$p,role:"teacher"}')"
expect_code 'teacher registration' 201
TT="$(value '.token')"
post register.php "$(jq -nc --arg n 'API Student' --arg e "$STUDENT_EMAIL" --arg p "$PASSWORD" '{full_name:$n,email:$e,password:$p,role:"student"}')"
expect_code 'student registration' 201
ST="$(value '.token')"
get me.php "$TT"; expect_jq 'authenticated profile' ".user.email == \"$TEACHER_EMAIL\""
get me.php; expect_code 'anonymous profile denied' 401
post login.php "$(jq -nc --arg e "$TEACHER_EMAIL" '{email:$e,password:"wrong password"}')"
expect_code 'wrong password denied' 401
expect_jq 'fixed JSON error envelope' '.error.code == "INVALID_CREDENTIALS"'

section classes-and-grants
post class_create.php '{"name":"API Test Class","description":"isolated e2e fixture","color":"#2563EB"}' "$TT"
expect_code 'teacher creates class' 201
CLASS_ID="$(value '.id')"
get code_get.php "$TT"; expect_code 'teacher gets active code' 200
TEACHER_CODE="$(value '.code')"
post code_lookup.php "$(jq -nc --arg c "$TEACHER_CODE" '{code:$c}')" "$ST"
expect_code 'student looks up code' 200
expect_jq 'lookup returns one-use grant' '.join_grant | length >= 32'
GRANT="$(value '.join_grant')"
post enroll.php "$(jq -nc --argjson c "$CLASS_ID" --arg g "$GRANT" '{class_id:$c,join_grant:$g}')" "$ST"
expect_code 'grant enrolls student' 200
post enroll.php "$(jq -nc --argjson c "$CLASS_ID" --arg g "$GRANT" '{class_id:$c,join_grant:$g}')" "$ST"
expect_code 'grant replay is rejected' 403
get "class_students.php?class_id=$CLASS_ID" "$TT"
expect_jq 'teacher sees enrolled student' '.students | length == 1'

section lessons-and-content
post lesson_create.php "$(jq -nc --argjson c "$CLASS_ID" '{class_id:$c,title:"Secure lesson"}')" "$TT"
expect_code 'teacher creates lesson' 201
LESSON_ID="$(value '.id')"
post content_create.php "$(jq -nc --argjson l "$LESSON_ID" '{lesson_id:$l,type:"note",title:"Note",body:"Visible to enrolled students"}')" "$TT"
expect_code 'teacher creates lesson content' 201
get "content_list.php?lesson_id=$LESSON_ID" "$ST"
expect_jq 'student reads enrolled content' '.contents[0].body == "Visible to enrolled students"'

section assessment-lifecycle
post assessment_create.php "$(jq -nc --argjson c "$CLASS_ID" '{class_id:$c,title:"Versioned quiz",kind:"quiz",duration_min:10,max_attempts:2,answer_release_policy:"immediately"}')" "$TT"
expect_code 'teacher creates draft assessment' 201
ASSESSMENT_ID="$(value '.id')"
post question_add.php "$(jq -nc --argjson a "$ASSESSMENT_ID" '{assessment_id:$a,text:"Two plus two?",type:"single_choice",points:2,options:[{text:"4",is_correct:true},{text:"5",is_correct:false}]}')" "$TT"
expect_code 'single-choice question added' 201
post question_add.php "$(jq -nc --argjson a "$ASSESSMENT_ID" '{assessment_id:$a,text:"Select values equal to one",type:"multiple_select",points:2,options:[{text:"1",is_correct:true},{text:"2/2",is_correct:true},{text:"1/2",is_correct:false}]}')" "$TT"
expect_code 'multiple-select question added' 201
post assessment_publish.php "$(jq -nc --argjson a "$ASSESSMENT_ID" '{assessment_id:$a}')" "$TT"
expect_code 'assessment publishes immutable snapshot' 200
post attempt_start.php "$(jq -nc --argjson a "$ASSESSMENT_ID" '{assessment_id:$a,idempotency_key:"api-test-start-0001"}')" "$ST"
expect_code 'student starts timed attempt' 201
expect_jq 'student payload hides answer keys' '[.questions[].options[] | has("is_correct")] | all(. == false)'
ATTEMPT_ID="$(value '.attempt.id')"
Q1="$(value '.questions[0].id')"; O1="$(value '.questions[0].options[0].id')"
Q2="$(value '.questions[1].id')"; O21="$(value '.questions[1].options[0].id')"; O22="$(value '.questions[1].options[1].id')"
ANSWERS="$(jq -nc --argjson a "$ATTEMPT_ID" --arg q1 "$Q1" --argjson o1 "$O1" --arg q2 "$Q2" --argjson o21 "$O21" --argjson o22 "$O22" '{attempt_id:$a,answers:{($q1):$o1,($q2):[$o21,$o22]}}')"
post attempt_submit.php "$ANSWERS" "$ST"
expect_code 'attempt submits by attempt id' 200
expect_jq 'objective attempt scores correctly' '.score == 100 and .status == "graded"'
get "attempt_get.php?id=$ATTEMPT_ID" "$ST"
expect_jq 'immediate answer release is honored' '.attempt.answers_released == true and (.answers | length == 2)'
post assessment_close.php "$(jq -nc --argjson a "$ASSESSMENT_ID" '{assessment_id:$a}')" "$TT"
expect_code 'teacher closes assessment' 200
post attempt_start.php "$(jq -nc --argjson a "$ASSESSMENT_ID" '{assessment_id:$a,idempotency_key:"api-test-start-0002"}')" "$ST"
expect_code 'closed assessment rejects new attempt' 409

section homework-versioning
post homework_create.php "$(jq -nc --argjson c "$CLASS_ID" '{class_id:$c,title:"Versioned homework",description:"Submit twice",allow_late_submission:true,allow_resubmit:true}')" "$TT"
expect_code 'teacher creates homework policy' 201
HOMEWORK_ID="$(value '.id')"
post submission_submit.php "$(jq -nc --argjson h "$HOMEWORK_ID" '{homework_id:$h,text:"first version"}')" "$ST"
expect_code 'student submits homework' 201
SUBMISSION_ID="$(value '.id')"
post submission_submit.php "$(jq -nc --argjson h "$HOMEWORK_ID" '{homework_id:$h,text:"improved version"}')" "$ST"
expect_jq 'resubmission creates version two' '.version_no == 2'
get "submission_history.php?submission_id=$SUBMISSION_ID" "$ST"
expect_jq 'student sees own immutable history' '.versions | length == 2'
get "submissions_list.php?homework_id=$HOMEWORK_ID" "$TT"
expect_jq 'teacher sees latest version' '.submissions[0].version_no == 2 and .submissions[0].text == "improved version"'
post submission_grade.php "$(jq -nc --argjson s "$SUBMISSION_ID" '{submission_id:$s,grade:"A",feedback:"Good revision"}')" "$TT"
expect_code 'teacher grades and gives feedback' 200
get "homework_list.php?class_id=$CLASS_ID" "$ST"
expect_jq 'student sees grade and feedback' '.homework[0].my_submission.grade == "A" and .homework[0].my_submission.feedback == "Good revision"'

section qa-dashboard-live
post qa_create.php "$(jq -nc --argjson c "$CLASS_ID" '{class_id:$c,title:"Question",body:"Please explain"}')" "$ST"
expect_code 'student creates Q&A thread' 201
THREAD_ID="$(value '.id')"
post qa_reply.php "$(jq -nc --argjson t "$THREAD_ID" '{thread_id:$t,body:"Teacher reply"}')" "$TT"
expect_code 'teacher replies to Q&A' 201
get "qa_thread.php?id=$THREAD_ID" "$ST"
expect_jq 'student sees teacher reply' '.replies[0].author_role == "teacher"'
get dashboard_teacher.php "$TT"; expect_jq 'teacher dashboard uses live data' '.stats.class_count >= 1 and .stats.student_count >= 1'
get dashboard_student.php "$ST"; expect_jq 'student dashboard uses live data' '.stats.class_count >= 1'
post live_start.php "$(jq -nc --argjson c "$CLASS_ID" '{class_id:$c}')" "$TT"
expect_code 'teacher starts backend-managed live room' 201
LIVE_ID="$(value '.session.id')"
post live_join.php "$(jq -nc --argjson s "$LIVE_ID" '{session_id:$s}')" "$ST"
expect_jq 'enrolled student receives HTTPS meeting URL' '.session.join_url | startswith("https://")'
post live_end.php "$(jq -nc --argjson s "$LIVE_ID" '{session_id:$s}')" "$TT"
expect_code 'teacher ends live room' 200

section account-and-demo
post profile_update.php '{"full_name":"Renamed Teacher"}' "$TT"
expect_jq 'profile update returns new name' '.user.full_name == "Renamed Teacher"'
post password_change.php "$(jq -nc --arg p "$PASSWORD" '{current_password:$p,new_password:"a newer secure password"}')" "$TT"
expect_code 'password change succeeds' 200
post login.php "$(jq -nc --arg e "$TEACHER_EMAIL" '{email:$e,password:"a newer secure password"}')"
expect_code 'new password can sign in' 200
post demo_start.php '{}'
expect_code 'isolated demo sandbox is created' 201
expect_jq 'demo advertises both roles and expiry' '(.roles | length == 2) and (.expires_at != null)'
DEMO_ID="$(value '.demo_id')"; DEMO_KEY="$(value '.access_key')"
post demo_login.php "$(jq -nc --arg d "$DEMO_ID" --arg k "$DEMO_KEY" '{demo_id:$d,access_key:$k,role:"student"}')"
expect_jq 'demo student login is scoped to generated identity' '.user.email | endswith("@demo.invalid")'

printf '\n== %d passed, %d failed ==\n' "$PASS" "$FAIL"
if (( FAIL > 0 )); then
  printf '\nServer log:\n' >&2
  tail -n 100 "$SERVER_LOG" >&2
  exit 1
fi
