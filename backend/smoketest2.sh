#!/bin/bash
set -e
BASE="http://localhost/OTMS1/backend/api"
PHP="/c/xampp/php/php.exe"
jget() { "$PHP" -r 'echo json_decode(file_get_contents("php://stdin"),true)["'"$1"'"] ?? "";'; }
H() { echo "-H Authorization:Bearer $1"; }

TT=$(curl -s -X POST $BASE/login.php -d '{"email":"teacher@otms.test","password":"password"}' | jget token)
ST=$(curl -s -X POST $BASE/login.php -d '{"email":"student@otms.test","password":"password"}' | jget token)

echo "== register second student =="
ST2=$(curl -s -X POST $BASE/register.php -H "Content-Type: application/json" -d '{"full_name":"Second Student","email":"student2@otms.test","password":"password","role":"student"}' | jget token)
[ -z "$ST2" ] && ST2=$(curl -s -X POST $BASE/login.php -d '{"email":"student2@otms.test","password":"password"}' | jget token)
# enroll student2 in class 1
curl -s -X POST $BASE/enroll.php -H "Authorization: Bearer $ST2" -d '{"class_id":1}' >/dev/null

echo "== student1 submits attempt & gets attempt id =="
AID=$(curl -s -X POST $BASE/attempt_submit.php -H "Authorization: Bearer $ST" -d '{"assessment_id":1,"answers":{"1":1,"2":5,"3":7,"4":"numerator","5":"It is part of a whole"}}' | jget attempt_id)
echo "attempt: $AID"

echo "== teacher lists attempts =="
curl -s "$BASE/attempts_list.php?assessment_id=1" -H "Authorization: Bearer $TT"; echo

echo "== teacher views attempt detail (find essay answer_id) =="
DET=$(curl -s "$BASE/attempt_get.php?id=$AID" -H "Authorization: Bearer $TT")
echo "$DET"; echo
# essay is question 5; there is no answer_id in payload — grade via answers table lookup endpoint uses answer_id.
# We need answer_id: query DB directly for demo.
ANS=$("/c/xampp/mysql/bin/mysql.exe" -u root -N -e "SELECT id FROM otms.answers WHERE attempt_id=${AID} AND question_id=5 LIMIT 1;" 2>/dev/null | tr -d '[:space:]')
echo "essay answer_id: $ANS"

echo "== teacher grades essay 3/3 =="
curl -s -X POST $BASE/essay_grade.php -H "Authorization: Bearer $TT" -d "{\"answer_id\":$ANS,\"points_earned\":3}"; echo

echo "== student1 submits homework 1 (text) =="
curl -s -X POST $BASE/submission_submit.php -H "Authorization: Bearer $ST" -d '{"homework_id":1,"text":"My answers for HW1"}'; echo

echo "== PRIVACY: student2 lists submissions for homework 1 (should see none of student1) =="
curl -s "$BASE/submissions_list.php?homework_id=1" -H "Authorization: Bearer $ST2"; echo

echo "== teacher lists submissions for homework 1 (should see student1) =="
curl -s "$BASE/submissions_list.php?homework_id=1" -H "Authorization: Bearer $TT"; echo

echo "== student1 posts Q&A, teacher replies =="
QID=$(curl -s -X POST $BASE/qa_create.php -H "Authorization: Bearer $ST" -d '{"class_id":1,"title":"What is a denominator?","body":"Confused about it."}' | jget id)
curl -s -X POST $BASE/qa_reply.php -H "Authorization: Bearer $TT" -d "{\"thread_id\":$QID,\"body\":\"The bottom number of a fraction.\"}" >/dev/null
curl -s "$BASE/qa_thread.php?id=$QID" -H "Authorization: Bearer $ST"; echo
