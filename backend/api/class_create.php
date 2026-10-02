<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$name = input_string($b, 'name', 120, true, 2);
$description = input_string($b, 'description', 5000, false) ?? '';
$color = isset($b['color']) && is_string($b['color']) ? strtoupper(trim($b['color'])) : '#6366F1';
if (!preg_match('/^#[0-9A-F]{6}$/', $color)) {
    fail('Color must be a six-digit hex value.', 422, 'VALIDATION_ERROR', ['color' => 'Example: #6366F1']);
}
$stmt = db()->prepare('INSERT INTO classes (teacher_id, name, description, color) VALUES (?,?,?,?)');
$stmt->execute([$user['id'], $name, $description === '' ? null : $description, $color]);
$id = (int)db()->lastInsertId();
audit_event((int)$user['id'], 'class.created', 'class', $id);
send(['id' => $id, 'name' => $name, 'description' => $description, 'color' => $color], 201);
