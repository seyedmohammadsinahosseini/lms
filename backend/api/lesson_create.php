<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$classId = (int)input_int($b, 'class_id', 1);
$title = input_string($b, 'title', 160, true, 1);
owned_class_or_fail($classId, (int)$user['id']);

$pdo = db();
$pdo->beginTransaction();
try {
    $lock = $pdo->prepare('SELECT id FROM classes WHERE id = ? FOR UPDATE');
    $lock->execute([$classId]);
    $pos = $pdo->prepare('SELECT COALESCE(MAX(position) + 1, 0) FROM lessons WHERE class_id = ?');
    $pos->execute([$classId]);
    $position = (int)$pos->fetchColumn();
    $pdo->prepare('INSERT INTO lessons (class_id, title, position) VALUES (?,?,?)')
        ->execute([$classId, $title, $position]);
    $id = (int)$pdo->lastInsertId();
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}
audit_event((int)$user['id'], 'lesson.created', 'lesson', $id);
send(['id' => $id, 'title' => $title, 'position' => $position], 201);
