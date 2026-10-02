<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
$user = require_auth();
require_role($user, 'student');
$stmt = db()->prepare(
    "SELECT
      (SELECT COUNT(*) FROM enrollments WHERE student_id = ?) AS class_count,
      (SELECT COUNT(*) FROM assessments a JOIN enrollments e ON e.class_id = a.class_id
        WHERE e.student_id = ? AND a.status = 'published'
          AND (a.opens_at IS NULL OR a.opens_at <= UTC_TIMESTAMP())
          AND (a.closes_at IS NULL OR a.closes_at > UTC_TIMESTAMP())) AS available_assessments,
      (SELECT COUNT(*) FROM homework h JOIN enrollments e ON e.class_id = h.class_id
        LEFT JOIN submissions s ON s.homework_id = h.id AND s.student_id = e.student_id
        WHERE e.student_id = ? AND s.id IS NULL
          AND (h.due_at IS NULL OR h.due_at >= UTC_TIMESTAMP() OR h.allow_late_submission = 1)) AS pending_homework,
      (SELECT ROUND(AVG(score),2) FROM attempts
        WHERE student_id = ? AND status = 'graded') AS average_score"
);
$stmt->execute(array_fill(0, 4, $user['id']));
$stats = $stmt->fetch();
$upcoming = db()->prepare(
    "SELECT a.id, a.title, a.kind, a.opens_at, a.closes_at, c.name AS class_name
     FROM assessments a JOIN classes c ON c.id = a.class_id
     JOIN enrollments e ON e.class_id = a.class_id
     WHERE e.student_id = ? AND a.status = 'published'
       AND (a.closes_at IS NULL OR a.closes_at > UTC_TIMESTAMP())
     ORDER BY COALESCE(a.opens_at, UTC_TIMESTAMP()), a.closes_at LIMIT 5"
);
$upcoming->execute([$user['id']]);
send(['stats' => [
    'class_count' => (int)$stats['class_count'],
    'available_assessments' => (int)$stats['available_assessments'],
    'pending_homework' => (int)$stats['pending_homework'],
    'average_score' => $stats['average_score'] === null ? null : (float)$stats['average_score'],
], 'upcoming_assessments' => array_map(static fn(array $r): array => [
    'id' => (int)$r['id'], 'title' => $r['title'], 'kind' => $r['kind'],
    'class_name' => $r['class_name'], 'opens_at' => iso_utc($r['opens_at']),
    'closes_at' => iso_utc($r['closes_at']),
], $upcoming->fetchAll())]);
