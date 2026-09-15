<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

$b = body();
$classId = (int)($b['class_id'] ?? 0);

owned_class_or_fail($classId, (int)$user['id']);

db()->prepare('DELETE FROM classes WHERE id = ?')->execute([$classId]);
send(['success' => true]);