<?php
declare(strict_types=1);
require_once __DIR__ . '/../assessment_service.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$assessmentId = (int)input_int($b, 'assessment_id', 1);
$release = input_bool($b, 'release', true);
$assessment = assessment_access_or_fail($assessmentId, $user);
owned_class_or_fail((int)$assessment['class_id'], (int)$user['id']);
db()->prepare('UPDATE assessments SET answers_released_at = ? WHERE id = ?')
    ->execute([$release ? gmdate('Y-m-d H:i:s') : null, $assessmentId]);
audit_event((int)$user['id'], $release ? 'assessment.answers_released' : 'assessment.answers_hidden', 'assessment', $assessmentId);
send(['success' => true, 'released' => $release]);
