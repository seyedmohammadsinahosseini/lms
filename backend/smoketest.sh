#!/bin/bash
# End-to-end API smoke test. Requires Apache+MySQL running and schema imported.
set -e
BASE="http://localhost/OTMS1/backend/api"
PHP="/c/xampp/php/php.exe"
jget() { "$PHP" -r 'echo json_decode(file_get_contents("php://stdin"),true)["'"$1"'"] ?? "";'; }

echo "== login teacher =="
TT=$(curl -s -X POST $BASE/login.php -H "Content-Type: application/json" -d '{"email":"teacher@otms.test","password":"password"}' | jget token)
echo "teacher token: ${TT:0:12}..."

echo "== teacher code =="
CODE=$(curl -s $BASE/code_get.php -H "Authorization: Bearer $TT" | jget code)
echo "code: $CODE"

echo "== login student =="
ST=$(curl -s -X POST $BASE/login.php -H "Content-Type: application/json" -d '{"email":"student@otms.test","password":"password"}' | jget token)
echo "student token: ${ST:0:12}..."

echo "== code lookup (student) =="
curl -s -X POST $BASE/code_lookup.php -H "Authorization: Bearer $ST" -H "Content-Type: application/json" -d "{\"code\":\"$CODE\"}"; echo

echo "== enroll student in class 2 (Physics) =="
curl -s -X POST $BASE/enroll.php -H "Authorization: Bearer $ST" -H "Content-Type: application/json" -d '{"class_id":2}'; echo

echo "== student classes =="
curl -s $BASE/classes_list.php -H "Authorization: Bearer $ST"; echo

echo "== lessons of class 1 (student) =="
curl -s "$BASE/lessons_list.php?class_id=1" -H "Authorization: Bearer $ST"; echo

echo "== contents of lesson 1 (student) =="
curl -s "$BASE/content_list.php?lesson_id=1" -H "Authorization: Bearer $ST"; echo

echo "== assessment 1 as student (no is_correct) =="
curl -s "$BASE/assessment_get.php?id=1" -H "Authorization: Bearer $ST"; echo

echo "== submit attempt (mc=correct opt1, tf=True opt5, yn=Yes opt7, fill=numerator, essay text) =="
curl -s -X POST $BASE/attempt_submit.php -H "Authorization: Bearer $ST" -H "Content-Type: application/json" \
  -d '{"assessment_id":1,"answers":{"1":1,"2":5,"3":7,"4":"numerator","5":"A part of a whole."}}'; echo
