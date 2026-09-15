<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

$b = body();
$homeworkId = (int)($b['homework_id'] ?? 0);

$stmt = db()->prepare('SELECT class_id FROM homework WHERE id = ?');
$stmt->execute([$homeworkId]);
$hw = $stmt->fetch();
if (!$hw) fail('Homework not found', 404);
owned_class_or_fail((int)$hw['class_id'], (int)$user['id']);

db()->prepare('DELETE FROM homework WHERE id = ?')->execute([$homeworkId]);
send(['success' => true]);