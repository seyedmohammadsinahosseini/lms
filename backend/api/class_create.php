<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

$b = body();
$name = trim($b['name'] ?? '');
$desc = trim($b['description'] ?? '');
$color = $b['color'] ?? '#6366F1';
if ($name === '') fail('Class name is required.');
if (!preg_match('/^#[0-9A-Fa-f]{6}$/', $color)) $color = '#6366F1';

$stmt = db()->prepare('INSERT INTO classes (teacher_id, name, description, color) VALUES (?,?,?,?)');
$stmt->execute([$user['id'], $name, $desc, $color]);
$id = (int)db()->lastInsertId();
send(['id' => $id, 'name' => $name, 'description' => $desc, 'color' => $color], 201);
