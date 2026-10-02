<?php
declare(strict_types=1);
require_once __DIR__ . '/../assessment_service.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$assessmentId = (int)input_int($b, 'assessment_id', 1);
$assessment = assessment_access_or_fail($assessmentId, $user);
owned_class_or_fail((int)$assessment['class_id'], (int)$user['id']);
$count = db()->prepare('SELECT COUNT(*) FROM attempts WHERE assessment_id = ?');
$count->execute([$assessmentId]);
if ((int)$count->fetchColumn() > 0) {
    fail('This assessment has attempts and cannot be deleted; close it instead.', 409, 'ASSESSMENT_HAS_ATTEMPTS');
}
db()->prepare('DELETE FROM assessments WHERE id = ?')->execute([$assessmentId]);
audit_event((int)$user['id'], 'assessment.deleted', 'assessment', $assessmentId);
send(['success' => true]);
