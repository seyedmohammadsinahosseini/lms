// Plain data models mirroring the API JSON. Kept lightweight (no codegen).

int _asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
double? _asDouble(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
bool _asBool(dynamic v) => v == true || v == 1 || v == '1';

class User {
  final int id;
  final String fullName;
  final String email;
  final String role; // teacher | student
  final int? avatarFileId;
  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.avatarFileId,
  });
  bool get isTeacher => role == 'teacher';
  factory User.fromJson(Map<String, dynamic> j) => User(
    id: _asInt(j['id']),
    fullName: j['full_name'] ?? '',
    email: j['email'] ?? '',
    role: j['role'] ?? 'student',
    avatarFileId: j['avatar_file_id'] == null
        ? null
        : _asInt(j['avatar_file_id']),
  );
}

class ClassModel {
  final int id;
  final String name;
  final String? description;
  final String color;
  final String? teacherName;
  final int? studentCount;
  ClassModel({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    this.teacherName,
    this.studentCount,
  });
  factory ClassModel.fromJson(Map<String, dynamic> j) => ClassModel(
    id: _asInt(j['id']),
    name: j['name'] ?? '',
    description: j['description'],
    color: j['color'] ?? '#6366F1',
    teacherName: j['teacher_name'],
    studentCount: j['student_count'] == null
        ? null
        : _asInt(j['student_count']),
  );
}

/// A class returned by code lookup, with enrollment flag for the student.
class LookupClass {
  final int id;
  final String name;
  final String? description;
  final String color;
  final bool enrolled;
  LookupClass({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    required this.enrolled,
  });
  factory LookupClass.fromJson(Map<String, dynamic> j) => LookupClass(
    id: _asInt(j['id']),
    name: j['name'] ?? '',
    description: j['description'],
    color: j['color'] ?? '#6366F1',
    enrolled: _asBool(j['enrolled']),
  );
}

class Lesson {
  final int id;
  final String title;
  final int position;
  Lesson({required this.id, required this.title, required this.position});
  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
    id: _asInt(j['id']),
    title: j['title'] ?? '',
    position: _asInt(j['position']),
  );
}

class Content {
  final int id;
  final String type; // video | note | booklet
  final String title;
  final String? body;
  final String? url;
  final String? filePath;
  Content({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.url,
    this.filePath,
  });
  factory Content.fromJson(Map<String, dynamic> j) => Content(
    id: _asInt(j['id']),
    type: j['type'] ?? 'note',
    title: j['title'] ?? '',
    body: j['body'],
    url: j['url'],
    filePath: j['file_path'],
  );
}

class AttemptSummary {
  final int id;
  final String status;
  final double? score;
  final String? deadlineAt;
  AttemptSummary({
    required this.id,
    required this.status,
    this.score,
    this.deadlineAt,
  });
  factory AttemptSummary.fromJson(Map<String, dynamic> j) => AttemptSummary(
    id: _asInt(j['id']),
    status: j['status'] ?? '',
    score: _asDouble(j['score']),
    deadlineAt: j['deadline_at'],
  );
}

class Assessment {
  final int id;
  final String title;
  final String? description;
  final String kind; // quiz | test | exam
  final String status; // draft | published | closed
  final int durationMin;
  final int maxAttempts;
  final int questionCount;
  final String? opensAt;
  final String? closesAt;
  final String answerReleasePolicy;
  final bool answersReleased;
  final AttemptSummary? attempt;
  Assessment({
    required this.id,
    required this.title,
    this.description,
    required this.kind,
    this.status = 'draft',
    required this.durationMin,
    this.maxAttempts = 1,
    required this.questionCount,
    this.opensAt,
    this.closesAt,
    this.answerReleasePolicy = 'teacher_release',
    this.answersReleased = false,
    this.attempt,
  });
  factory Assessment.fromJson(Map<String, dynamic> j) => Assessment(
    id: _asInt(j['id']),
    title: j['title'] ?? '',
    description: j['description'],
    kind: j['kind'] ?? 'quiz',
    status: j['status'] ?? 'draft',
    durationMin: _asInt(j['duration_min']),
    maxAttempts: _asInt(j['max_attempts']) < 1 ? 1 : _asInt(j['max_attempts']),
    questionCount: _asInt(j['question_count']),
    opensAt: j['opens_at'],
    closesAt: j['closes_at'],
    answerReleasePolicy: j['answer_release_policy'] ?? 'teacher_release',
    answersReleased: _asBool(j['answers_released']),
    attempt: j['attempt'] == null
        ? null
        : AttemptSummary.fromJson(Map<String, dynamic>.from(j['attempt'])),
  );
}

class Option {
  final int id;
  final String text;
  final bool? isCorrect; // present only for teachers
  Option({required this.id, required this.text, this.isCorrect});
  factory Option.fromJson(Map<String, dynamic> j) => Option(
    id: _asInt(j['id']),
    text: j['text'] ?? '',
    isCorrect: j.containsKey('is_correct') ? _asBool(j['is_correct']) : null,
  );
}

class Question {
  final int id;
  final String text;
  final String type;
  final int points;
  final List<Option> options;
  Question({
    required this.id,
    required this.text,
    required this.type,
    required this.points,
    required this.options,
  });
  factory Question.fromJson(Map<String, dynamic> j) => Question(
    id: _asInt(j['id']),
    text: j['text'] ?? '',
    type: j['type'] ?? '',
    points: _asInt(j['points']),
    options: ((j['options'] ?? []) as List)
        .map((o) => Option.fromJson(Map<String, dynamic>.from(o)))
        .toList(),
  );
}

class AttemptAnswer {
  final int? answerId;
  final int questionId;
  final String text;
  final String type;
  final int points;
  final String? answerText;
  final String? chosenOption;
  final String? correctAnswer;
  final int? pointsEarned;
  final String? gradingStatus;
  final bool? isCorrect;
  AttemptAnswer({
    this.answerId,
    required this.questionId,
    required this.text,
    required this.type,
    required this.points,
    this.answerText,
    this.chosenOption,
    this.correctAnswer,
    this.pointsEarned,
    this.gradingStatus,
    this.isCorrect,
  });
  factory AttemptAnswer.fromJson(Map<String, dynamic> j) => AttemptAnswer(
    answerId: j['answer_id'] == null ? null : _asInt(j['answer_id']),
    questionId: _asInt(j['question_id']),
    text: j['text'] ?? '',
    type: j['type'] ?? '',
    points: _asInt(j['points']),
    answerText: j['answer_text'],
    chosenOption: j['chosen_option'],
    correctAnswer: j['correct_answer'],
    pointsEarned: j['points_earned'] == null
        ? null
        : _asInt(j['points_earned']),
    gradingStatus: j['grading_status'],
    isCorrect: j['is_correct'] == null ? null : _asBool(j['is_correct']),
  );
}

class Attempt {
  final int id;
  final int studentId;
  final String studentName;
  final int attemptNo;
  final double? score;
  final String status;
  final String? startedAt;
  final String? deadlineAt;
  final String? submittedAt;
  Attempt({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.attemptNo = 1,
    this.score,
    required this.status,
    this.startedAt,
    this.deadlineAt,
    this.submittedAt,
  });
  factory Attempt.fromJson(Map<String, dynamic> j) => Attempt(
    id: _asInt(j['id']),
    studentId: _asInt(j['student_id']),
    studentName: j['student_name'] ?? '',
    attemptNo: _asInt(j['attempt_no']),
    score: _asDouble(j['score']),
    status: j['status'] ?? '',
    startedAt: j['started_at'],
    deadlineAt: j['deadline_at'],
    submittedAt: j['submitted_at'],
  );
}

class Homework {
  final int id;
  final String title;
  final String? description;
  final String? dueDate;
  final String? dueAt;
  final bool allowLateSubmission;
  final bool allowResubmit;
  final String? resubmitUntil;
  final Map<String, dynamic>? mySubmission;
  final int? submissionCount;
  final int? pendingCount;
  Homework({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.dueAt,
    this.allowLateSubmission = false,
    this.allowResubmit = true,
    this.resubmitUntil,
    this.mySubmission,
    this.submissionCount,
    this.pendingCount,
  });
  factory Homework.fromJson(Map<String, dynamic> j) => Homework(
    id: _asInt(j['id']),
    title: j['title'] ?? '',
    description: j['description'],
    dueDate: j['due_date'],
    dueAt: j['due_at'],
    allowLateSubmission: _asBool(j['allow_late_submission']),
    allowResubmit: j.containsKey('allow_resubmit')
        ? _asBool(j['allow_resubmit'])
        : true,
    resubmitUntil: j['resubmit_until'],
    mySubmission: j['my_submission'] == null
        ? null
        : Map<String, dynamic>.from(j['my_submission']),
    submissionCount: j['submission_count'] == null
        ? null
        : _asInt(j['submission_count']),
    pendingCount: j['pending_count'] == null
        ? null
        : _asInt(j['pending_count']),
  );
}

class Submission {
  final int id;
  final int studentId;
  final String studentName;
  final int versionNo;
  final String status;
  final String? text;
  final String? filePath;
  final String? submittedAt;
  final bool isLate;
  final String? grade;
  final String? feedback;
  final String? gradedAt;
  Submission({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.versionNo = 1,
    this.status = 'pending_grading',
    this.text,
    this.filePath,
    this.submittedAt,
    this.isLate = false,
    this.grade,
    this.feedback,
    this.gradedAt,
  });
  factory Submission.fromJson(Map<String, dynamic> j) => Submission(
    id: _asInt(j['id']),
    studentId: _asInt(j['student_id']),
    studentName: j['student_name'] ?? '',
    versionNo: _asInt(j['version_no']),
    status: j['status'] ?? 'pending_grading',
    text: j['text'],
    filePath: j['file_path'],
    submittedAt: j['submitted_at'],
    isLate: _asBool(j['is_late']),
    grade: j['grade'],
    feedback: j['feedback'],
    gradedAt: j['graded_at'],
  );
}

class SubmissionVersion {
  final int versionNo;
  final String? text;
  final String? filePath;
  final String? submittedAt;
  final bool isLate;
  SubmissionVersion({
    required this.versionNo,
    this.text,
    this.filePath,
    this.submittedAt,
    this.isLate = false,
  });
  factory SubmissionVersion.fromJson(Map<String, dynamic> j) =>
      SubmissionVersion(
        versionNo: _asInt(j['version_no']),
        text: j['text'],
        filePath: j['file_path'],
        submittedAt: j['submitted_at'],
        isLate: _asBool(j['is_late']),
      );
}

class QaThread {
  final int id;
  final String title;
  final String? body;
  final String authorName;
  final int replyCount;
  final String? createdAt;
  QaThread({
    required this.id,
    required this.title,
    this.body,
    required this.authorName,
    required this.replyCount,
    this.createdAt,
  });
  factory QaThread.fromJson(Map<String, dynamic> j) => QaThread(
    id: _asInt(j['id']),
    title: j['title'] ?? '',
    body: j['body'],
    authorName: j['author_name'] ?? '',
    replyCount: _asInt(j['reply_count']),
    createdAt: j['created_at'],
  );
}

class QaReply {
  final int id;
  final String body;
  final String authorName;
  final String authorRole;
  final String? createdAt;
  QaReply({
    required this.id,
    required this.body,
    required this.authorName,
    required this.authorRole,
    this.createdAt,
  });
  factory QaReply.fromJson(Map<String, dynamic> j) => QaReply(
    id: _asInt(j['id']),
    body: j['body'] ?? '',
    authorName: j['author_name'] ?? '',
    authorRole: j['author_role'] ?? '',
    createdAt: j['created_at'],
  );
}

// ---- Composite responses (assembled by ApiClient) --------------------------

/// One enrolled student, as seen by a teacher on the roster.
class StudentRow {
  final int id;
  final String fullName;
  final String email;
  final String? joinedAt;
  StudentRow({
    required this.id,
    required this.fullName,
    required this.email,
    this.joinedAt,
  });
  factory StudentRow.fromJson(Map<String, dynamic> j) => StudentRow(
    id: _asInt(j['id']),
    fullName: j['full_name'] ?? '',
    email: j['email'] ?? '',
    joinedAt: j['joined_at'],
  );
}

/// Result of a teacher-code lookup: the teacher plus their offered classes.
class CodeLookup {
  final int teacherId;
  final String teacherName;
  final String joinGrant;
  final List<LookupClass> classes;
  CodeLookup({
    required this.teacherId,
    required this.teacherName,
    this.joinGrant = '',
    required this.classes,
  });
}

/// An assessment with its full question set (for taking or authoring).
class AssessmentDetail {
  final int id;
  final int classId;
  final String title;
  final String? description;
  final String kind;
  final String status;
  final int durationMin;
  final int maxAttempts;
  final String? opensAt;
  final String? closesAt;
  final List<Question> questions;
  AssessmentDetail({
    required this.id,
    required this.classId,
    required this.title,
    this.description,
    required this.kind,
    this.status = 'draft',
    required this.durationMin,
    this.maxAttempts = 1,
    this.opensAt,
    this.closesAt,
    required this.questions,
  });
}

/// Server-created attempt plus its immutable question snapshot.
class StartedAttempt {
  final int attemptId;
  final int attemptNo;
  final String? startedAt;
  final String? deadlineAt;
  final AssessmentDetail assessment;
  StartedAttempt({
    required this.attemptId,
    required this.attemptNo,
    this.startedAt,
    this.deadlineAt,
    required this.assessment,
  });
}

/// Returned right after submitting an attempt.
class AttemptResult {
  final int attemptId;
  final double? score;
  final bool pendingEssay;
  AttemptResult({
    required this.attemptId,
    this.score,
    required this.pendingEssay,
  });
}

/// Full graded attempt: header + per-question answers.
class AttemptDetail {
  final int id;
  final String assessmentTitle;
  final double? score;
  final String status;
  final bool answersReleased;
  final String? deadlineAt;
  final List<AttemptAnswer> answers;
  AttemptDetail({
    required this.id,
    required this.assessmentTitle,
    this.score,
    required this.status,
    this.answersReleased = false,
    this.deadlineAt,
    required this.answers,
  });
}

/// A Q&A thread with its replies.
class QaThreadDetail {
  final QaThread thread;
  final List<QaReply> replies;
  QaThreadDetail({required this.thread, required this.replies});
}

class LiveSession {
  final int id;
  final int classId;
  final String provider;
  final String status;
  final String? room;
  final String? joinUrl;
  final String? token;
  final String? startsAt;
  LiveSession({
    required this.id,
    required this.classId,
    required this.provider,
    required this.status,
    this.room,
    this.joinUrl,
    this.token,
    this.startsAt,
  });
  factory LiveSession.fromJson(Map<String, dynamic> j) => LiveSession(
    id: _asInt(j['id']),
    classId: _asInt(j['class_id']),
    provider: j['provider'] ?? 'jitsi',
    status: j['status'] ?? 'live',
    room: j['room'],
    joinUrl: j['join_url'],
    token: j['token'],
    startsAt: j['starts_at'],
  );
}

class DemoAccess {
  final String demoId;
  final String accessKey;
  final String? expiresAt;
  DemoAccess({required this.demoId, required this.accessKey, this.expiresAt});
}

class DashboardData {
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> items;
  DashboardData({required this.stats, this.items = const []});
}
