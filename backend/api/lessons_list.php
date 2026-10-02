<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
$user = require_auth();
$classId = filter_var($_GET['class_id'] ?? null, FILTER_VALIDATE_INT);
if (!$classId) fail('class_id is required.', 422, 'VALIDATION_ERROR');
class_access_or_fail((int)$classId, $user);
$stmt = db()->prepare('SELECT id, title, position FROM lessons WHERE class_id = ? ORDER BY position, id');
$stmt->execute([$classId]);
$lessons = array_map(static fn(array $r): array => [
    'id' => (int)$r['id'], 'title' => $r['title'], 'position' => (int)$r['position'],
], $stmt->fetchAll());
send(['lessons' => $lessons]);
