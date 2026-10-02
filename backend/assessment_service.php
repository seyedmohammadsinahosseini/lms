<?php
declare(strict_types=1);

require_once __DIR__ . '/helpers.php';

function assessment_current_version(array $assessment): array {
    $stmt = db()->prepare(
        'SELECT * FROM assessment_versions WHERE assessment_id = ? AND version_no = ?'
    );
    $stmt->execute([$assessment['id'], $assessment['current_version_no']]);
    $version = $stmt->fetch();
    if (!$version) throw new RuntimeException('Assessment version is missing.');
    return $version;
}

function assessment_latest_published_version(int $assessmentId): ?array {
    $stmt = db()->prepare(
        'SELECT * FROM assessment_versions
         WHERE assessment_id = ? AND is_published = 1
         ORDER BY version_no DESC LIMIT 1'
    );
    $stmt->execute([$assessmentId]);
    return $stmt->fetch() ?: null;
}

/**
 * Returns questions keyed numerically, each with an `options` array. Two SQL
 * queries are used regardless of question count.
 */
function assessment_questions(int $versionId): array {
    $stmt = db()->prepare(
        'SELECT id, text, type, points, position FROM questions
         WHERE assessment_version_id = ? ORDER BY position, id'
    );
    $stmt->execute([$versionId]);
    $questions = $stmt->fetchAll();
    if ($questions === []) return [];

    $byId = [];
    foreach ($questions as &$question) {
        $question['id'] = (int)$question['id'];
        $question['points'] = (float)$question['points'];
        $question['position'] = (int)$question['position'];
        $question['options'] = [];
        $byId[$question['id']] = &$question;
    }
    unset($question);

    $ids = array_keys($byId);
    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $stmt = db()->prepare(
        "SELECT id, question_id, text, is_correct, position FROM options
         WHERE question_id IN ({$placeholders}) ORDER BY question_id, position, id"
    );
    $stmt->execute($ids);
    foreach ($stmt->fetchAll() as $option) {
        $qid = (int)$option['question_id'];
        $byId[$qid]['options'][] = [
            'id' => (int)$option['id'],
            'question_id' => $qid,
            'text' => $option['text'],
            'is_correct' => (bool)$option['is_correct'],
            'position' => (int)$option['position'],
        ];
    }
    return $questions;
}

function serialize_questions(array $questions, bool $includeCorrect): array {
    return array_map(static function (array $question) use ($includeCorrect): array {
        $options = [];
        foreach ($question['options'] as $option) {
            $item = ['id' => (int)$option['id'], 'text' => $option['text']];
            if ($includeCorrect) $item['is_correct'] = (bool)$option['is_correct'];
            $options[] = $item;
        }
        // A fill-blank option is an answer key, not a choice shown to students.
        if (!$includeCorrect && $question['type'] === 'fill_blank') $options = [];
        return [
            'id' => (int)$question['id'],
            'text' => $question['text'],
            'type' => $question['type'],
            'points' => (float)$question['points'],
            'position' => (int)$question['position'],
            'options' => $options,
        ];
    }, $questions);
}

/**
 * Must be called inside a transaction after locking the assessment. A published
 * version is immutable; this clones it into a new editable draft version.
 */
function ensure_editable_assessment_version(array $assessment): array {
    $current = assessment_current_version($assessment);
    if (!(bool)$current['is_published']) return $current;

    $nextNo = (int)$assessment['current_version_no'] + 1;
    db()->prepare(
        'INSERT INTO assessment_versions (assessment_id, version_no, is_published)
         VALUES (?,?,0)'
    )->execute([$assessment['id'], $nextNo]);
    $newVersionId = (int)db()->lastInsertId();

    $questions = assessment_questions((int)$current['id']);
    $insertQuestion = db()->prepare(
        'INSERT INTO questions (assessment_version_id, text, type, points, position)
         VALUES (?,?,?,?,?)'
    );
    $insertOption = db()->prepare(
        'INSERT INTO options (question_id, text, is_correct, position) VALUES (?,?,?,?)'
    );
    foreach ($questions as $question) {
        $insertQuestion->execute([
            $newVersionId, $question['text'], $question['type'],
            $question['points'], $question['position'],
        ]);
        $newQuestionId = (int)db()->lastInsertId();
        foreach ($question['options'] as $option) {
            $insertOption->execute([
                $newQuestionId, $option['text'], $option['is_correct'] ? 1 : 0, $option['position'],
            ]);
        }
    }
    db()->prepare('UPDATE assessments SET current_version_no = ? WHERE id = ?')
        ->execute([$nextNo, $assessment['id']]);
    $current['id'] = $newVersionId;
    $current['version_no'] = $nextNo;
    $current['is_published'] = 0;
    return $current;
}

function assessment_is_open(array $assessment): bool {
    $now = time();
    if ($assessment['status'] !== 'published') return false;
    if ($assessment['opens_at'] && strtotime($assessment['opens_at'] . ' UTC') > $now) return false;
    if ($assessment['closes_at'] && strtotime($assessment['closes_at'] . ' UTC') <= $now) return false;
    return true;
}

function assessment_answers_released(array $assessment): bool {
    return match ($assessment['answer_release_policy']) {
        'immediately' => true,
        'after_close' => $assessment['closes_at'] !== null
            && strtotime($assessment['closes_at'] . ' UTC') <= time(),
        'teacher_release' => $assessment['answers_released_at'] !== null,
        default => false,
    };
}

function recalculate_attempt(int $attemptId): array {
    $stmt = db()->prepare(
        'SELECT COALESCE(SUM(q.points),0) AS total,
                COALESCE(SUM(a.points_earned),0) AS earned,
                SUM(a.grading_status = \'pending\') AS pending
         FROM attempts at
         JOIN questions q ON q.assessment_version_id = at.assessment_version_id
         LEFT JOIN answers a ON a.attempt_id = at.id AND a.question_id = q.id
         WHERE at.id = ?'
    );
    $stmt->execute([$attemptId]);
    $totals = $stmt->fetch();
    $total = (float)$totals['total'];
    $earned = (float)$totals['earned'];
    $pending = (int)$totals['pending'];
    $score = $total > 0 ? round($earned / $total * 100, 2) : 0.0;
    $status = $pending > 0 ? 'pending_grading' : 'graded';
    db()->prepare('UPDATE attempts SET score = ?, status = ? WHERE id = ?')
        ->execute([$score, $status, $attemptId]);
    return ['score' => $score, 'status' => $status, 'pending_essay' => $pending > 0];
}
