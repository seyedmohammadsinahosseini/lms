<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

db()->prepare('UPDATE teacher_codes SET active = 0 WHERE teacher_id = ?')->execute([$user['id']]);
do {
    $code = strtoupper(bin2hex(random_bytes(3)));
    $c = db()->prepare('SELECT 1 FROM teacher_codes WHERE code = ?');
    $c->execute([$code]);
} while ($c->fetch());
db()->prepare('INSERT INTO teacher_codes (teacher_id, code) VALUES (?,?)')->execute([$user['id'], $code]);
send(['code' => $code]);
