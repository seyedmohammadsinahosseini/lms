<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
$user = require_auth();
require_role($user, 'teacher');
$stmt = db()->prepare(
    'SELECT code, created_at FROM teacher_codes
     WHERE teacher_id = ? AND active = 1 ORDER BY id DESC LIMIT 1'
);
$stmt->execute([$user['id']]);
$row = $stmt->fetch();
send(['code' => $row['code'] ?? null, 'created_at' => iso_utc($row['created_at'] ?? null)]);
