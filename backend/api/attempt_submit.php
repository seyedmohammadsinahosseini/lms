<?php
// Student submits an attempt. Body: assessment_id, answers { question_id: value }.
// value is an option_id (mc/tf/yes_no) or a string (fill_blank/essay).
// Auto-grades objective types; essays are stored with is_correct=null (pending).
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'student');
require_method('POST');

$b = body();
$assessmentId = (int)($b['assessment_id'] ?? 0);
$answers = $b['answers'] ?? [];
if (!is_array($answers)) $answers = [];

$stmt = db()->prepare('SELECT * FROM assessments WHERE id = ?');
$stmt->execute([$assessmentId]);
$a = $stmt->fetch();
if (!$a) fail('Assessment not found', 404);
enrolled_or_fail((int)$a['class_id'], (int)$user['id']);

// Load questions + options.
$qs = db()->prepare('SELECT * FROM questions WHERE assessment_id = ?');
$qs->execute([$assessmentId]);
$questions = [];
foreach ($qs->fetchAll() as $q) {
    $o = db()->prepare('SELECT * FROM options WHERE question_id = ?');
    $o->execute([$q['id']]);
    $q['options'] = $o->fetchAll();
    $questions[$q['id']] = $q;
}

db()->beginTransaction();
try {
    $stmt = db()->prepare(
        "INSERT INTO attempts (assessment_id, student_id, submitted_at, status)
         VALUES (?,?, NOW(), 'completed')"
    );
    $stmt->execute([$assessmentId, $user['id']]);
    $attemptId = (int)db()->lastInsertId();

    $totalPoints = 0;
    $earned = 0;
    $hasPendingEssay = false;

    $insA = db()->prepare(
        'INSERT INTO answers (attempt_id, question_id, option_id, answer_text, points_earned, is_correct)
         VALUES (?,?,?,?,?,?)'
    );

    foreach ($questions as $qid => $q) {
        $totalPoints += (int)$q['points'];
        $given = $answers[$qid] ?? ($answers[(string)$qid] ?? null);
        $optionId = null; $answerText = null; $pts = null; $isCorrect = null;

        if ($q['type'] === 'essay') {
            $answerText = is_string($given) ? $given : null;
            $hasPendingEssay = true; // needs manual grade
        } elseif ($q['type'] === 'fill_blank') {
            $answerText = is_string($given) ? $given : '';
            $correct = $q['options'][0]['text'] ?? '';
            $isCorrect = strtolower(trim($answerText)) === strtolower(trim($correct)) ? 1 : 0;
            $pts = $isCorrect ? (int)$q['points'] : 0;
            $earned += $pts;
        } else { // multiple_choice, true_false, yes_no -> option id
            $optionId = (int)$given ?: null;
            $isCorrect = 0; $pts = 0;
            foreach ($q['options'] as $opt) {
                if ((int)$opt['id'] === $optionId && (int)$opt['is_correct'] === 1) {
                    $isCorrect = 1; $pts = (int)$q['points']; break;
                }
            }
            $earned += $pts;
        }
        $insA->execute([$attemptId, $qid, $optionId, $answerText, $pts, $isCorrect]);
    }

    // Score is the objective percentage now; essays adjust it at grading time.
    $score = $totalPoints > 0 ? round($earned / $totalPoints * 100, 2) : 0;
    $status = $hasPendingEssay ? 'completed' : 'graded';
    db()->prepare('UPDATE attempts SET score = ?, status = ? WHERE id = ?')
        ->execute([$score, $status, $attemptId]);

    db()->commit();
} catch (Throwable $e) {
    db()->rollBack();
    fail('Could not submit attempt.', 500);
}

send([
    'attempt_id' => $attemptId,
    'score' => $score,
    'pending_essay' => $hasPendingEssay,
], 201);
