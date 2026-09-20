import 'dart:typed_data';

import '../models/models.dart';

/// The contract the app depends on for all data.
///
/// Every screen, provider and test talks to this interface, never to a
/// concrete backend. Two implementations are planned:
///
///   * `ApiClient` -- the HTTP client that talks to the PHP backend. This is
///     the existing implementation and stays the default for now.
///   * a local, offline implementation backed by SQLite that ships inside the
///     app, so the app can run on a phone with no server at all. That is what
///     this seam exists for; it lands in a later step.
///
/// Callers obtain the active implementation from `Api.instance`
/// (see `services/api.dart`), the single place the choice is made.
///
/// Keep this file free of HTTP, files and plugins: it describes *what* the app
/// needs, not *how* any one backend provides it.
abstract class OmsApi {
  /// Called when the backend rejects the stored session, so the app can drop it
  /// and show the login screen again. An on-device implementation that has no
  /// session expiry may simply never call it.
  void Function()? onUnauthorized;

  /// Restores a previously stored session, if any. Called once at startup.
  Future<void> loadToken();

  /// Turns a stored file reference into something the platform can open: an
  /// HTTP URL for a remote backend, a local path for an on-device one.
  String fileUrl(String relativePath);

  Future<User> register({ required String fullName, required String email, required String password, required String role, });
  Future<User> login(String email, String password);
  Future<User?> me();
  Future<void> logout();
  Future<String?> getCode();
  Future<String> regenerateCode();
  Future<CodeLookup> lookupCode(String code);
  Future<List<ClassModel>> classes();
  Future<ClassModel> createClass(String name, String description, String color);
  Future<void> enroll(int classId);
  Future<void> deleteClass(int classId);
  Future<List<StudentRow>> classStudents(int classId);
  Future<List<Lesson>> lessons(int classId);
  Future<Lesson> createLesson(int classId, String title);
  Future<List<Content>> contents(int lessonId);
  Future<void> createContent({ required int lessonId, required String type, required String title, String? body, String? url, Uint8List? fileBytes, String? fileName, });
  Future<void> deleteLesson(int lessonId);
  Future<void> deleteContent(int contentId);
  Future<List<Assessment>> assessments(int classId);
  Future<int> createAssessment({ required int classId, required String title, required String description, required String kind, required int durationMin, });
  Future<void> deleteAssessment(int assessmentId);
  Future<void> addQuestion(Map<String, dynamic> payload);
  Future<void> deleteQuestion(int questionId);
  Future<AssessmentDetail> assessmentDetail(int id);
  Future<AttemptResult> submitAttempt( int assessmentId, Map<int, dynamic> answers);
  Future<List<Attempt>> attempts(int assessmentId);
  Future<AttemptDetail> attemptDetail(int id);
  Future<void> gradeEssay(int answerId, int pointsEarned);
  Future<List<Homework>> homework(int classId);
  Future<void> createHomework({ required int classId, required String title, required String description, String? dueDate, });
  Future<void> deleteHomework(int homeworkId);
  Future<void> submitHomework({ required int homeworkId, String? text, Uint8List? fileBytes, String? fileName, });
  Future<List<Submission>> submissions(int homeworkId);
  Future<void> gradeSubmission( int submissionId, String grade, String feedback);
  Future<void> deleteSubmission(int submissionId);
  Future<List<QaThread>> qaThreads(int classId);
  Future<int> createThread(int classId, String title, String body);
  Future<void> replyThread(int threadId, String body);
  Future<QaThreadDetail> qaThread(int id);
}
