<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
$classId = (int)($_GET['class_id'] ?? 0);
class_access_or_fail($classId, $user);

$stmt = db()->prepare('SELECT * FROM lessons WHERE class_id = ? ORDER BY position, id');
$stmt->execute([$classId]);
$lessons = array_map(fn($l) => [
    'id' => (int)$l['id'],
    'title' => $l['title'],
    'position' => (int)$l['position'],
], $stmt->fetchAll());
send(['lessons' => $lessons]);
