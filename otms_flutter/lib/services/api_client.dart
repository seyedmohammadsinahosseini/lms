import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/env.dart';
import '../models/models.dart';

/// Thrown for any failed API call. [message] is safe to show to the user.
class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);

  /// The request never produced an HTTP response: offline, DNS failure, refused
  /// connection, or timeout.
  ApiException.network(this.message) : status = 0;

  bool get isNetworkError => status == 0;
  bool get isUnauthorized => status == 401;
  bool get isServerError => status >= 500;

  @override
  String toString() => message;
}

/// The single HTTP layer for the whole app. Every backend call goes through
/// here, so swapping to a hosted API or Firebase later touches only this file.
class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  /// The app-wide instance. Reassignable so tests can inject a mock-backed
  /// client; see `test/api_client_test.dart`.
  static ApiClient instance = ApiClient();

  /// Base URL of the backend, from `Env` (see `core/config/env.dart`).
  static String get base => Env.apiBaseUrl;
  static String get apiBase => Env.apiBase;

  /// How long a single request may take before it is treated as a failure.
  static const Duration requestTimeout = Duration(seconds: 15);

  /// Extra attempts allowed for GET requests on a transport failure. Worst case
  /// for a data screen is therefore 2 x 15s plus backoff, not an unbounded hang.
  static const int _maxRetries = 1;

  static const _tokenKey = 'otms_token';

  final http.Client _http;
  String? _token;

  String? get token => _token;

  /// Called when the server rejects the stored token, so the app can drop the
  /// session instead of showing errors on every screen forever.
  void Function()? onUnauthorized;

  /// Turns a stored relative file path (e.g. "uploads/ab12.pdf") into a URL.
  String fileUrl(String relativePath) => '$base/$relativePath';

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> _setToken(String? value) async {
    _token = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, value);
    }
  }

  Map<String, String> get _authHeaders =>
      {if (_token != null) 'Authorization': 'Bearer $_token'};

  // ---- Core request helpers ------------------------------------------------

  Uri _uri(String path, [Map<String, dynamic>? query]) => Uri.parse(
        '$apiBase/$path',
      ).replace(
        queryParameters:
            query?.map((k, v) => MapEntry(k, '$v')),
      );

  dynamic _decode(http.Response res) {
    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        data = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (res.statusCode == 401 && _token != null) {
      // A stored token was rejected: drop it so the app doesn't keep replaying
      // it, and let the auth layer return to the login screen.
      unawaited(_setToken(null));
      onUnauthorized?.call();
    }
    final msg = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : 'Request failed (${res.statusCode})';
    throw ApiException(msg, res.statusCode);
  }

  /// Runs [request] with a timeout and turns transport failures into
  /// [ApiException]s with a message worth showing.
  ///
  /// [retry] is only safe for requests that can be replayed. A POST may already
  /// have reached the server (submitting an attempt, uploading a file), so
  /// replaying it could apply the change twice; it is also skipped on startup,
  /// where retrying just keeps the user on the splash screen.
  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required bool retry,
  }) async {
    final maxAttempts = retry ? _maxRetries + 1 : 1;
    for (var attempt = 1;; attempt++) {
      try {
        return await request().timeout(requestTimeout);
      } on TimeoutException {
        if (attempt >= maxAttempts) {
          throw ApiException.network(
            'The server took too long to respond. Check your connection and try again.',
          );
        }
      } on http.ClientException {
        if (attempt >= maxAttempts) {
          throw ApiException.network(
            'Could not reach the server at $base. Check your connection and '
            'that the backend is running.',
          );
        }
      }
      // Linear backoff: 300ms, then 600ms.
      await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
    }
  }

  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async {
    final res = await _send(
      () => _http.get(_uri(path, query), headers: _authHeaders),
      retry: true,
    );
    return _decode(res);
  }

  /// A GET that is never retried, for calls where a long wait is worse than an
  /// immediate error (the startup token check).
  Future<dynamic> _getOnce(String path) async {
    final res = await _send(
      () => _http.get(_uri(path), headers: _authHeaders),
      retry: false,
    );
    return _decode(res);
  }

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    final res = await _send(
      () => _http.post(
        _uri(path),
        headers: {..._authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode(body ?? {}),
      ),
      retry: false,
    );
    return _decode(res);
  }

  /// Multipart POST for file uploads. [fields] are string form values;
  /// [fileBytes]/[fileName] attach a single `file` part when present.
  Future<dynamic> _postMultipart(
    String path, {
    required Map<String, String> fields,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final req = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_authHeaders)
      ..fields.addAll(fields);
    if (fileBytes != null && fileName != null) {
      req.files.add(http.MultipartFile.fromBytes('file', fileBytes,
          filename: fileName));
    }
    final res = await _send(
      () async => http.Response.fromStream(await _http.send(req)),
      retry: false,
    );
    return _decode(res);
  }

  // ---- Auth ----------------------------------------------------------------

  Future<User> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final data = await _post('register.php', {
      'full_name': fullName,
      'email': email,
      'password': password,
      'role': role,
    });
    await _setToken(data['token']);
    return User.fromJson(Map<String, dynamic>.from(data['user']));
  }

  Future<User> login(String email, String password) async {
    final data =
        await _post('login.php', {'email': email, 'password': password});
    await _setToken(data['token']);
    return User.fromJson(Map<String, dynamic>.from(data['user']));
  }

  Future<User?> me() async {
    if (_token == null) return null;
    try {
      final data = await _getOnce('me.php');
      return User.fromJson(Map<String, dynamic>.from(data['user']));
    } on ApiException catch (e) {
      // _decode has already cleared the stored token and notified
      // onUnauthorized for a 401.
      if (e.isUnauthorized) return null;
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _post('logout.php');
    } catch (_) {
      // Ignore network errors on logout; clear the local token regardless.
    }
    await _setToken(null);
  }

  // ---- Teacher codes -------------------------------------------------------

  Future<String?> getCode() async => (await _get('code_get.php'))['code'];

  Future<String> regenerateCode() async =>
      (await _post('code_regenerate.php'))['code'];

  /// Student looks up a teacher code; returns teacher info + selectable classes.
  Future<CodeLookup> lookupCode(String code) async {
    final data = await _post('code_lookup.php', {'code': code});
    return CodeLookup(
      teacherId: _asIntPub(data['teacher']['id']),
      teacherName: data['teacher']['full_name'] ?? '',
      classes: ((data['classes'] ?? []) as List)
          .map((c) => LookupClass.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
    );
  }

  // ---- Classes -------------------------------------------------------------

  Future<List<ClassModel>> classes() async {
    final data = await _get('classes_list.php');
    return ((data['classes'] ?? []) as List)
        .map((c) => ClassModel.fromJson(Map<String, dynamic>.from(c)))
        .toList();
  }

  Future<ClassModel> createClass(String name, String description,
      String color) async {
    final data = await _post('class_create.php',
        {'name': name, 'description': description, 'color': color});
    return ClassModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> enroll(int classId) async =>
      _post('enroll.php', {'class_id': classId});

  Future<void> deleteClass(int classId) async =>
      _post('class_delete.php', {'class_id': classId});

  Future<List<StudentRow>> classStudents(int classId) async {
    final data = await _get('class_students.php', {'class_id': classId});
    return ((data['students'] ?? []) as List)
        .map((s) => StudentRow.fromJson(Map<String, dynamic>.from(s)))
        .toList();
  }

  // ---- Lessons & content ---------------------------------------------------

  Future<List<Lesson>> lessons(int classId) async {
    final data = await _get('lessons_list.php', {'class_id': classId});
    return ((data['lessons'] ?? []) as List)
        .map((l) => Lesson.fromJson(Map<String, dynamic>.from(l)))
        .toList();
  }

  Future<Lesson> createLesson(int classId, String title) async {
    final data =
        await _post('lesson_create.php', {'class_id': classId, 'title': title});
    return Lesson.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<Content>> contents(int lessonId) async {
    final data = await _get('content_list.php', {'lesson_id': lessonId});
    return ((data['contents'] ?? []) as List)
        .map((c) => Content.fromJson(Map<String, dynamic>.from(c)))
        .toList();
  }

  /// Create content. For `video` pass [url]; for note/booklet pass [body];
  /// optionally attach a file via [fileBytes]/[fileName].
  Future<void> createContent({
    required int lessonId,
    required String type,
    required String title,
    String? body,
    String? url,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    if (fileBytes != null && fileName != null) {
      await _postMultipart('content_create.php', fields: {
        'lesson_id': '$lessonId',
        'type': type,
        'title': title,
        'body': ?body,
        'url': ?url,
      }, fileBytes: fileBytes, fileName: fileName);
    } else {
      await _post('content_create.php', {
        'lesson_id': lessonId,
        'type': type,
        'title': title,
        'body': ?body,
        'url': ?url,
      });
    }
  }

  Future<void> deleteLesson(int lessonId) async =>
      _post('lesson_delete.php', {'lesson_id': lessonId});

  Future<void> deleteContent(int contentId) async =>
      _post('content_delete.php', {'content_id': contentId});

  // ---- Assessments ---------------------------------------------------------

  Future<List<Assessment>> assessments(int classId) async {
    final data = await _get('assessments_list.php', {'class_id': classId});
    return ((data['assessments'] ?? []) as List)
        .map((a) => Assessment.fromJson(Map<String, dynamic>.from(a)))
        .toList();
  }

  Future<int> createAssessment({
    required int classId,
    required String title,
    required String description,
    required String kind,
    required int durationMin,
  }) async {
    final data = await _post('assessment_create.php', {
      'class_id': classId,
      'title': title,
      'description': description,
      'kind': kind,
      'duration_min': durationMin,
    });
    return _asIntPub(data['id']);
  }

  Future<void> deleteAssessment(int assessmentId) async =>
      _post('assessment_delete.php', {'assessment_id': assessmentId});

  /// Adds a question. [payload] must already carry type-specific fields
  /// (options[] / correct / answer) per the backend contract.
  Future<void> addQuestion(Map<String, dynamic> payload) async =>
      _post('question_add.php', payload);

  Future<void> deleteQuestion(int questionId) async =>
      _post('question_delete.php', {'question_id': questionId});

  Future<AssessmentDetail> assessmentDetail(int id) async {
    final data = await _get('assessment_get.php', {'id': id});
    return AssessmentDetail(
      id: _asIntPub(data['assessment']['id']),
      classId: _asIntPub(data['assessment']['class_id']),
      title: data['assessment']['title'] ?? '',
      description: data['assessment']['description'],
      kind: data['assessment']['kind'] ?? 'quiz',
      durationMin: _asIntPub(data['assessment']['duration_min']),
      questions: ((data['questions'] ?? []) as List)
          .map((q) => Question.fromJson(Map<String, dynamic>.from(q)))
          .toList(),
    );
  }

  /// Submit an attempt. [answers] maps question id -> option id (int) or text.
  Future<AttemptResult> submitAttempt(
      int assessmentId, Map<int, dynamic> answers) async {
    final data = await _post('attempt_submit.php', {
      'assessment_id': assessmentId,
      'answers': answers.map((k, v) => MapEntry('$k', v)),
    });
    return AttemptResult(
      attemptId: _asIntPub(data['attempt_id']),
      score: (data['score'] as num?)?.toDouble(),
      pendingEssay: data['pending_essay'] == true,
    );
  }

  Future<List<Attempt>> attempts(int assessmentId) async {
    final data = await _get('attempts_list.php', {'assessment_id': assessmentId});
    return ((data['attempts'] ?? []) as List)
        .map((a) => Attempt.fromJson(Map<String, dynamic>.from(a)))
        .toList();
  }

  Future<AttemptDetail> attemptDetail(int id) async {
    final data = await _get('attempt_get.php', {'id': id});
    return AttemptDetail(
      id: _asIntPub(data['attempt']['id']),
      assessmentTitle: data['attempt']['assessment_title'] ?? '',
      score: (data['attempt']['score'] as num?)?.toDouble(),
      status: data['attempt']['status'] ?? '',
      answers: ((data['answers'] ?? []) as List)
          .map((a) => AttemptAnswer.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
    );
  }

  Future<void> gradeEssay(int answerId, int pointsEarned) async =>
      _post('essay_grade.php',
          {'answer_id': answerId, 'points_earned': pointsEarned});

  // ---- Homework ------------------------------------------------------------

  Future<List<Homework>> homework(int classId) async {
    final data = await _get('homework_list.php', {'class_id': classId});
    return ((data['homework'] ?? []) as List)
        .map((h) => Homework.fromJson(Map<String, dynamic>.from(h)))
        .toList();
  }

  Future<void> createHomework({
    required int classId,
    required String title,
    required String description,
    String? dueDate,
  }) async =>
      _post('homework_create.php', {
        'class_id': classId,
        'title': title,
        'description': description,
        'due_date': ?dueDate,
      });

  Future<void> deleteHomework(int homeworkId) async =>
      _post('homework_delete.php', {'homework_id': homeworkId});

  Future<void> submitHomework({
    required int homeworkId,
    String? text,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    if (fileBytes != null && fileName != null) {
      await _postMultipart('submission_submit.php', fields: {
        'homework_id': '$homeworkId',
        'text': ?text,
      }, fileBytes: fileBytes, fileName: fileName);
    } else {
      await _post('submission_submit.php',
          {'homework_id': homeworkId, 'text': ?text});
    }
  }

  Future<List<Submission>> submissions(int homeworkId) async {
    final data = await _get('submissions_list.php', {'homework_id': homeworkId});
    return ((data['submissions'] ?? []) as List)
        .map((s) => Submission.fromJson(Map<String, dynamic>.from(s)))
        .toList();
  }

  Future<void> gradeSubmission(
          int submissionId, String grade, String feedback) async =>
      _post('submission_grade.php', {
        'submission_id': submissionId,
        'grade': grade,
        'feedback': feedback,
      });

  Future<void> deleteSubmission(int submissionId) async =>
      _post('submission_delete.php', {'submission_id': submissionId});

  // ---- Q&A -----------------------------------------------------------------

  Future<List<QaThread>> qaThreads(int classId) async {
    final data = await _get('qa_list.php', {'class_id': classId});
    return ((data['threads'] ?? []) as List)
        .map((t) => QaThread.fromJson(Map<String, dynamic>.from(t)))
        .toList();
  }

  Future<int> createThread(int classId, String title, String body) async {
    final data = await _post('qa_create.php',
        {'class_id': classId, 'title': title, 'body': body});
    return _asIntPub(data['id']);
  }

  Future<void> replyThread(int threadId, String body) async =>
      _post('qa_reply.php', {'thread_id': threadId, 'body': body});

  Future<QaThreadDetail> qaThread(int id) async {
    final data = await _get('qa_thread.php', {'id': id});
    return QaThreadDetail(
      thread: QaThread.fromJson(Map<String, dynamic>.from(data['thread'])),
      replies: ((data['replies'] ?? []) as List)
          .map((r) => QaReply.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
    );
  }
}

int _asIntPub(dynamic v) =>
    v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
