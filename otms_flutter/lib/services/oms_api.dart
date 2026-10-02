import 'dart:typed_data';

import '../models/models.dart';

/// Complete data contract used by the app. Existing method signatures remain
/// stable for test fakes; newly introduced capabilities have default
/// implementations so focused fakes only override what a test exercises.
abstract class OmsApi {
  void Function()? onUnauthorized;

  Future<void> loadToken();
  String fileUrl(String relativePath);

  Future<User> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? teacherInvite,
  });
  Future<User> login(String email, String password);
  Future<User?> me();
  Future<void> logout();

  Future<String?> getCode();
  Future<String> regenerateCode();
  Future<CodeLookup> lookupCode(String code);
  Future<List<ClassModel>> classes();
  Future<ClassModel> createClass(String name, String description, String color);

  /// Uses the one-time grant returned by the most recent [lookupCode].
  Future<void> enroll(int classId);
  Future<void> deleteClass(int classId);
  Future<List<StudentRow>> classStudents(int classId);

  Future<List<Lesson>> lessons(int classId);
  Future<Lesson> createLesson(int classId, String title);
  Future<List<Content>> contents(int lessonId);
  Future<void> createContent({
    required int lessonId,
    required String type,
    required String title,
    String? body,
    String? url,
    Uint8List? fileBytes,
    String? fileName,
  });
  Future<void> deleteLesson(int lessonId);
  Future<void> deleteContent(int contentId);

  Future<List<Assessment>> assessments(int classId);
  Future<int> createAssessment({
    required int classId,
    required String title,
    required String description,
    required String kind,
    required int durationMin,
    int maxAttempts = 1,
    String? opensAt,
    String? closesAt,
    String answerReleasePolicy = 'teacher_release',
  });
  Future<void> deleteAssessment(int assessmentId);
  Future<void> addQuestion(Map<String, dynamic> payload);
  Future<void> deleteQuestion(int questionId);
  Future<AssessmentDetail> assessmentDetail(int id);

  /// [assessmentOrAttemptId] is an attempt id after [startAttempt]. The name is
  /// retained for source compatibility with older focused test fakes.
  Future<AttemptResult> submitAttempt(
    int assessmentOrAttemptId,
    Map<int, dynamic> answers,
  );
  Future<List<Attempt>> attempts(int assessmentId);
  Future<AttemptDetail> attemptDetail(int id);
  Future<void> gradeEssay(int answerId, int pointsEarned);

  Future<List<Homework>> homework(int classId);
  Future<void> createHomework({
    required int classId,
    required String title,
    required String description,
    String? dueDate,
    bool allowLateSubmission = false,
    bool allowResubmit = true,
    String? resubmitUntil,
  });
  Future<void> deleteHomework(int homeworkId);
  Future<void> submitHomework({
    required int homeworkId,
    String? text,
    Uint8List? fileBytes,
    String? fileName,
  });
  Future<List<Submission>> submissions(int homeworkId);
  Future<List<SubmissionVersion>> submissionHistory(int submissionId);
  Future<void> gradeSubmission(int submissionId, String grade, String feedback);
  Future<void> deleteSubmission(int submissionId);

  Future<List<QaThread>> qaThreads(int classId);
  Future<int> createThread(int classId, String title, String body);
  Future<void> replyThread(int threadId, String body);
  Future<QaThreadDetail> qaThread(int id);

  // Version 2 capabilities ---------------------------------------------------
  Future<StartedAttempt> startAttempt(int assessmentId) =>
      Future.error(UnimplementedError('startAttempt'));
  Future<void> publishAssessment(int assessmentId) =>
      Future.error(UnimplementedError('publishAssessment'));
  Future<void> closeAssessment(int assessmentId) =>
      Future.error(UnimplementedError('closeAssessment'));
  Future<void> releaseAssessmentAnswers(int assessmentId, bool release) =>
      Future.error(UnimplementedError('releaseAssessmentAnswers'));

  Future<User> updateProfile(String fullName) =>
      Future.error(UnimplementedError('updateProfile'));
  Future<void> changePassword(String currentPassword, String newPassword) =>
      Future.error(UnimplementedError('changePassword'));

  Future<DashboardData> dashboard() =>
      Future.error(UnimplementedError('dashboard'));

  Future<LiveSession?> currentLive(int classId) =>
      Future.error(UnimplementedError('currentLive'));
  Future<LiveSession> startLive(int classId) =>
      Future.error(UnimplementedError('startLive'));
  Future<LiveSession> joinLive(int sessionId) =>
      Future.error(UnimplementedError('joinLive'));
  Future<void> endLive(int sessionId) =>
      Future.error(UnimplementedError('endLive'));

  Future<DemoAccess> createDemo() =>
      Future.error(UnimplementedError('createDemo'));
  Future<User> loginDemo(DemoAccess access, String role) =>
      Future.error(UnimplementedError('loginDemo'));
}
