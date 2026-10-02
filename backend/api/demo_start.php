<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
if (!otms_demo_mode()) fail('Demo mode is disabled.', 404, 'NOT_FOUND');
enforce_rate_limit('demo_start', client_ip(), 3, 3600, 3600);

// Delete expired sandboxes and their physical uploads before creating another.
$stmt = db()->query(
    'SELECT sf.storage_name FROM stored_files sf JOIN users u ON u.id = sf.owner_user_id
     JOIN demo_sessions d ON d.id = u.demo_session_id WHERE d.expires_at <= UTC_TIMESTAMP()'
);
foreach ($stmt->fetchAll(PDO::FETCH_COLUMN) as $storageName) {
    @unlink(otms_storage_path() . DIRECTORY_SEPARATOR . basename((string)$storageName));
}
db()->exec('DELETE FROM demo_sessions WHERE expires_at <= UTC_TIMESTAMP()');

$publicId = bin2hex(random_bytes(16));
$accessKey = new_token();
$expiresAt = gmdate('Y-m-d H:i:s', time() + 7200);
$pdo = db();
$pdo->beginTransaction();
try {
    $pdo->prepare(
        'INSERT INTO demo_sessions (public_id, access_key_hash, expires_at, created_by_ip_hash)
         VALUES (?,?,?,?)'
    )->execute([$publicId, token_hash($accessKey), $expiresAt, privacy_hash(client_ip())]);
    $demoId = (int)$pdo->lastInsertId();
    $unusablePassword = password_hash(new_token(), PASSWORD_DEFAULT);
    $insertUser = $pdo->prepare(
        'INSERT INTO users (demo_session_id, full_name, email, password_hash, role) VALUES (?,?,?,?,?)'
    );
    $insertUser->execute([$demoId, 'Demo Teacher', "teacher-{$publicId}@demo.invalid", $unusablePassword, 'teacher']);
    $teacherId = (int)$pdo->lastInsertId();
    $insertUser->execute([$demoId, 'Demo Student', "student-{$publicId}@demo.invalid", $unusablePassword, 'student']);
    $studentId = (int)$pdo->lastInsertId();
    $pdo->prepare('INSERT INTO teacher_codes (teacher_id, code) VALUES (?,?)')
        ->execute([$teacherId, generate_teacher_code()]);

    $pdo->prepare('INSERT INTO classes (teacher_id, name, description, color) VALUES (?,?,?,?)')
        ->execute([$teacherId, 'Mathematics Demo', 'An isolated portfolio sandbox. Changes disappear after two hours.', '#6366F1']);
    $classId = (int)$pdo->lastInsertId();
    $pdo->prepare('INSERT INTO enrollments (class_id, student_id) VALUES (?,?)')->execute([$classId, $studentId]);
    $pdo->prepare('INSERT INTO lessons (class_id, title, position) VALUES (?,?,0)')
        ->execute([$classId, 'Fractions and equations']);
    $lessonId = (int)$pdo->lastInsertId();
    $content = $pdo->prepare('INSERT INTO contents (lesson_id, type, title, body, url) VALUES (?,?,?,?,?)');
    $content->execute([$lessonId, 'note', 'Key definitions', "A fraction represents part of a whole.\n\nThe numerator is above the denominator.", null]);
    $content->execute([$lessonId, 'video', 'Video lesson', null, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ']);

    $pdo->prepare(
        "INSERT INTO assessments
         (class_id, title, description, kind, status, duration_min, max_attempts,
          answer_release_policy, current_version_no, published_at)
         VALUES (?,?,?,'quiz','published',10,2,'immediately',1,UTC_TIMESTAMP())"
    )->execute([$classId, 'Fractions quiz', 'All supported question types are represented.']);
    $assessmentId = (int)$pdo->lastInsertId();
    $pdo->prepare(
        'INSERT INTO assessment_versions (assessment_id, version_no, is_published, published_at)
         VALUES (?,1,1,UTC_TIMESTAMP())'
    )->execute([$assessmentId]);
    $versionId = (int)$pdo->lastInsertId();
    $insertQuestion = $pdo->prepare(
        'INSERT INTO questions (assessment_version_id, text, type, points, position) VALUES (?,?,?,?,?)'
    );
    $insertOption = $pdo->prepare(
        'INSERT INTO options (question_id, text, is_correct, position) VALUES (?,?,?,?)'
    );
    $seedQuestions = [
        ['What is 1/2 + 1/2?', 'single_choice', 2, [['1',1],['2',0],['1/4',0]]],
        ['Select all values equal to one.', 'multiple_select', 2, [['1',1],['2/2',1],['1/2',0]]],
        ['A fraction has a numerator.', 'true_false', 1, [['True',1],['False',0]]],
        ['Is 3/3 equal to one?', 'yes_no', 1, [['Yes',1],['No',0]]],
        ['The top number is the _____.', 'fill_blank', 1, [['numerator',1]]],
        ['Explain a fraction in your own words.', 'essay', 3, []],
    ];
    foreach ($seedQuestions as $position => [$questionText, $type, $points, $options]) {
        $insertQuestion->execute([$versionId, $questionText, $type, $points, $position]);
        $questionId = (int)$pdo->lastInsertId();
        foreach ($options as $optionPosition => [$optionText, $correct]) {
            $insertOption->execute([$questionId, $optionText, $correct, $optionPosition]);
        }
    }

    $pdo->prepare(
        'INSERT INTO homework
         (class_id, title, description, due_at, allow_late_submission, allow_resubmit, resubmit_until)
         VALUES (?,?,?,DATE_ADD(UTC_TIMESTAMP(), INTERVAL 7 DAY),1,1,DATE_ADD(UTC_TIMESTAMP(), INTERVAL 10 DAY))'
    )->execute([$classId, 'Fractions worksheet', 'Submit text or upload a small document.']);
    $pdo->prepare('INSERT INTO qa_threads (class_id, student_id, title, body) VALUES (?,?,?,?)')
        ->execute([$classId, $studentId, 'Can I resubmit homework?', 'I would like to improve my first submission.']);
    $threadId = (int)$pdo->lastInsertId();
    $pdo->prepare('INSERT INTO qa_replies (thread_id, author_id, body) VALUES (?,?,?)')
        ->execute([$threadId, $teacherId, 'Yes. This demo assignment allows versioned resubmission.']);
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}

audit_event(null, 'demo.created', 'demo_session', $demoId);
send([
    'demo_id' => $publicId, 'access_key' => $accessKey,
    'expires_at' => iso_utc($expiresAt),
    'roles' => ['teacher', 'student'],
], 201);
