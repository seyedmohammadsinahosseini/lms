<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
$user = require_auth();
require_role($user, 'teacher');
$stmt = db()->prepare(
    "SELECT
      (SELECT COUNT(*) FROM classes WHERE teacher_id = ?) AS class_count,
      (SELECT COUNT(DISTINCT e.student_id) FROM enrollments e JOIN classes c ON c.id = e.class_id
        WHERE c.teacher_id = ?) AS student_count,
      (SELECT COUNT(*) FROM submissions s JOIN homework h ON h.id = s.homework_id
        JOIN classes c ON c.id = h.class_id
        WHERE c.teacher_id = ? AND s.status IN ('pending_grading','late')) AS pending_homework,
      (SELECT COUNT(*) FROM answers ans JOIN attempts at ON at.id = ans.attempt_id
        JOIN assessments a ON a.id = at.assessment_id JOIN classes c ON c.id = a.class_id
        WHERE c.teacher_id = ? AND ans.grading_status = 'pending') AS pending_essays,
      (SELECT ROUND(AVG(at.score),2) FROM attempts at JOIN assessments a ON a.id = at.assessment_id
        JOIN classes c ON c.id = a.class_id WHERE c.teacher_id = ? AND at.status = 'graded') AS average_score"
);
$stmt->execute(array_fill(0, 5, $user['id']));
$stats = $stmt->fetch();
$recent = db()->prepare(
    'SELECT s.id, s.status, s.updated_at, u.full_name AS student_name,
            h.title AS homework_title, c.name AS class_name
     FROM submissions s JOIN users u ON u.id = s.student_id
     JOIN homework h ON h.id = s.homework_id JOIN classes c ON c.id = h.class_id
     WHERE c.teacher_id = ? ORDER BY s.updated_at DESC LIMIT 5'
);
$recent->execute([$user['id']]);
send(['stats' => [
    'class_count' => (int)$stats['class_count'], 'student_count' => (int)$stats['student_count'],
    'pending_homework' => (int)$stats['pending_homework'], 'pending_essays' => (int)$stats['pending_essays'],
    'average_score' => $stats['average_score'] === null ? null : (float)$stats['average_score'],
], 'recent_submissions' => array_map(static fn(array $r): array => [
    'id' => (int)$r['id'], 'status' => $r['status'], 'student_name' => $r['student_name'],
    'homework_title' => $r['homework_title'], 'class_name' => $r['class_name'],
    'updated_at' => iso_utc($r['updated_at']),
], $recent->fetchAll())]);
