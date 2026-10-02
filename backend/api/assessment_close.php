<?php
declare(strict_types=1);
require_once __DIR__ . '/../assessment_service.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$body = body();
$assessmentId = (int)input_int($body, 'assessment_id', 1);
$stmt = db()->prepare('SELECT * FROM assessments WHERE id = ?');
$stmt->execute([$assessmentId]);
$assessment = $stmt->fetch();
if (!$assessment) fail('Assessment not found.', 404, 'NOT_FOUND');
owned_class_or_fail((int)$assessment['class_id'], (int)$user['id']);
if ($assessment['status'] !== 'published') {
    fail('Only a published assessment can be closed.', 409, 'INVALID_STATE');
}
db()->prepare("UPDATE assessments SET status = 'closed' WHERE id = ?")
    ->execute([$assessmentId]);
audit_event((int)$user['id'], 'assessment.closed', 'assessment', $assessmentId);
send(['success' => true, 'status' => 'closed']);
