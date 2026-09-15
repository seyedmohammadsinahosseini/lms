<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

$b = body();
$assessmentId = (int)($b['assessment_id'] ?? 0);

$stmt = db()->prepare('SELECT class_id FROM assessments WHERE id = ?');
$stmt->execute([$assessmentId]);
$a = $stmt->fetch();
if (!$a) fail('Assessment not found', 404);
owned_class_or_fail((int)$a['class_id'], (int)$user['id']);

db()->prepare('DELETE FROM assessments WHERE id = ?')->execute([$assessmentId]);
send(['success' => true]);