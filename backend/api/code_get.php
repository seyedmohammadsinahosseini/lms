<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
$stmt = db()->prepare('SELECT code FROM teacher_codes WHERE teacher_id = ? AND active = 1 ORDER BY id DESC LIMIT 1');
$stmt->execute([$user['id']]);
$row = $stmt->fetch();
send(['code' => $row['code'] ?? null]);
