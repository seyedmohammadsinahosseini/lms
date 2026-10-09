import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/config/env.dart';
import '../core/network/http_client_factory.dart';
import '../core/storage/session_store.dart';
import '../models/models.dart';
import 'lms_api.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  final String code;
  final Map<String, dynamic> fields;

  ApiException(
    this.message,
    this.status, {
    this.code = 'REQUEST_FAILED',
    this.fields = const {},
  });

  ApiException.network(this.message)
    : status = 0,
      code = 'NETWORK_ERROR',
      fields = const {};

  bool get isNetworkError => status == 0;
  bool get isUnauthorized => status == 401;
  bool get isServerError => status >= 500;

  @override
  String toString() => message;
}

class ApiClient implements LmsApi {
  ApiClient({http.Client? httpClient, SessionStore? sessionStore})
    : _http = httpClient ?? createHttpClient(),
      _sessionStore = sessionStore ?? SessionStore();

  static String get apiBase => Env.apiBase;
  static const Duration requestTimeout = Duration(seconds: 20);
  static const int _maxRetries = 1;

  final http.Client _http;
  final SessionStore _sessionStore;
  final Uuid _uuid = const Uuid();

  String? _token;
  String? _csrfToken;
  String? _joinGrant;
  String? _userRole;

  String? get token => _token;

  @override
  void Function()? onUnauthorized;

  @override
  String fileUrl(String relativePath) {
    final parsed = Uri.tryParse(relativePath);
    if (parsed != null && parsed.hasScheme) return relativePath;
    return '$apiBase/${relativePath.startsWith('/') ? relativePath.substring(1) : relativePath}';
  }

  @override
  Future<void> loadToken() async {
    _token = await _sessionStore.readToken();
    if (kIsWeb) {
      // A page refresh retains the HttpOnly cookie but not the in-memory CSRF
      // token. Rotate it through an authenticated, read-only endpoint.
      try {
        final data = await _getOnce('csrf.php');
        _csrfToken = data['csrf_token'] as String?;
      } on ApiException catch (error) {
        if (!error.isUnauthorized) rethrow;
      }
    }
  }

  Future<void> _setToken(String? token) async {
    _token = token;
    await _sessionStore.writeToken(token);
  }

  Map<String, String> get _baseHeaders => {
    'X-LMS-Client': kIsWeb ? 'web' : 'native',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Map<String, String> get _mutationHeaders => {
    ..._baseHeaders,
    'X-CSRF-Token': ?_csrfToken,
  };

  Uri _uri(String path, [Map<String, dynamic>? query]) =>
      Uri.parse('$apiBase/$path').replace(
        queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
      );

  dynamic _decode(http.Response response) {
    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = null;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    if (response.statusCode == 401) {
      final hadSession = _token != null || _userRole != null;
      unawaited(_setToken(null));
      _csrfToken = null;
      _userRole = null;
      if (hadSession) onUnauthorized?.call();
    }

    var message = 'Request failed (${response.statusCode})';
    var code = 'REQUEST_FAILED';
    var fields = <String, dynamic>{};
    if (data is Map && data['error'] is Map) {
      final error = Map<String, dynamic>.from(data['error'] as Map);
      message = error['message']?.toString() ?? message;
      code = error['code']?.toString() ?? code;
      if (error['fields'] is Map) {
        fields = Map<String, dynamic>.from(error['fields'] as Map);
      }
    } else if (data is Map && data['error'] != null) {
      message = data['error'].toString();
    }
    throw ApiException(
      message,
      response.statusCode,
      code: code,
      fields: fields,
    );
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required bool retry,
  }) async {
    final attempts = retry ? _maxRetries + 1 : 1;
    for (var attempt = 1; ; attempt++) {
      try {
        return await request().timeout(requestTimeout);
      } on TimeoutException {
        if (attempt >= attempts) {
          throw ApiException.network(
            'The server at $apiBase took too long to respond. Check your connection and try again.',
          );
        }
      } on http.ClientException {
        if (attempt >= attempts) {
          throw ApiException.network(
            'Could not reach the LMS server at $apiBase. Check your connection and try again.',
          );
        }
      }
      await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
    }
  }

  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async {
    final response = await _send(
      () => _http.get(_uri(path, query), headers: _baseHeaders),
      retry: true,
    );
    return _decode(response);
  }

  Future<dynamic> _getOnce(String path, [Map<String, dynamic>? query]) async {
    final response = await _send(
      () => _http.get(_uri(path, query), headers: _baseHeaders),
      retry: false,
    );
    return _decode(response);
  }

  Future<dynamic> _post(
    String path, [
    Map<String, dynamic>? body,
    bool retry = false,
  ]) async {
    final response = await _send(
      () => _http.post(
        _uri(path),
        headers: {..._mutationHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
      retry: retry,
    );
    return _decode(response);
  }

  Future<dynamic> _postMultipart(
    String path, {
    required Map<String, String> fields,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_mutationHeaders)
      ..fields.addAll(fields);
    if (fileBytes != null && fileName != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );
    }
    final response = await _send(
      () async => http.Response.fromStream(await _http.send(request)),
      retry: false,
    );
    return _decode(response);
  }

  Future<User> _acceptSession(dynamic data) async {
    await _setToken(data['token'] as String?);
    _csrfToken = data['csrf_token'] as String?;
    final user = User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    _userRole = user.role;
    return user;
  }

  @override
  Future<User> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? teacherInvite,
  }) async => _acceptSession(
    await _post('register.php', {
      'full_name': fullName,
      'email': email,
      'password': password,
      'role': role,
      if (teacherInvite != null && teacherInvite.isNotEmpty)
        'teacher_invite': teacherInvite,
    }),
  );

  @override
  Future<User> login(String email, String password) async => _acceptSession(
    await _post('login.php', {'email': email, 'password': password}),
  );

  @override
  Future<User?> me() async {
    if (!kIsWeb && _token == null) return null;
    try {
      final data = await _getOnce('me.php');
      final user = User.fromJson(
        Map<String, dynamic>.from(data['user'] as Map),
      );
      _userRole = user.role;
      return user;
    } on ApiException catch (error) {
      if (error.isUnauthorized) return null;
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _post('logout.php');
    } catch (_) {
      // Local session state is cleared even if the network is unavailable.
    }
    await _setToken(null);
    _csrfToken = null;
    _userRole = null;
    _joinGrant = null;
  }

  @override
  Future<User> updateProfile(String fullName) async {
    final data = await _post('profile_update.php', {'full_name': fullName});
    return User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async => _post('password_change.php', {
    'current_password': currentPassword,
    'new_password': newPassword,
  });

  @override
  Future<String?> getCode() async => (await _get('code_get.php'))['code'];

  @override
  Future<String> regenerateCode() async =>
      (await _post('code_regenerate.php'))['code'] as String;

  @override
  Future<CodeLookup> lookupCode(String code) async {
    final data = await _post('code_lookup.php', {'code': code});
    _joinGrant = data['join_grant'] as String?;
    return CodeLookup(
      teacherId: _asIntPub(data['teacher']['id']),
      teacherName: data['teacher']['full_name'] ?? '',
      joinGrant: _joinGrant ?? '',
      classes: ((data['classes'] ?? const []) as List)
          .map(
            (item) =>
                LookupClass.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }

  @override
  Future<List<ClassModel>> classes() async {
    final data = await _get('classes_list.php', {'per_page': 100});
    return ((data['classes'] ?? const []) as List)
        .map(
          (item) => ClassModel.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  Future<ClassModel> createClass(
    String name,
    String description,
    String color,
  ) async {
    final data = await _post('class_create.php', {
      'name': name,
      'description': description,
      'color': color,
    });
    return ClassModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<void> enroll(int classId) async {
    if (_joinGrant == null) {
      throw ApiException(
        'Look up the teacher code again before joining a class.',
        409,
        code: 'JOIN_GRANT_REQUIRED',
      );
    }
    await _post('enroll.php', {'class_id': classId, 'join_grant': _joinGrant});
    _joinGrant = null;
  }

  @override
  Future<void> deleteClass(int classId) async =>
      _post('class_delete.php', {'class_id': classId});

  @override
  Future<List<StudentRow>> classStudents(int classId) async {
    final data = await _get('class_students.php', {
      'class_id': classId,
      'per_page': 100,
    });
    return ((data['students'] ?? const []) as List)
        .map(
          (item) => StudentRow.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  Future<List<Lesson>> lessons(int classId) async {
    final data = await _get('lessons_list.php', {'class_id': classId});
    return ((data['lessons'] ?? const []) as List)
        .map((item) => Lesson.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<Lesson> createLesson(int classId, String title) async {
    final data = await _post('lesson_create.php', {
      'class_id': classId,
      'title': title,
    });
    return Lesson.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<List<Content>> contents(int lessonId) async {
    final data = await _get('content_list.php', {'lesson_id': lessonId});
    return ((data['contents'] ?? const []) as List)
        .map((item) => Content.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
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
      await _postMultipart(
        'content_create.php',
        fields: {
          'lesson_id': '$lessonId',
          'type': type,
          'title': title,
          'body': ?body,
          'url': ?url,
        },
        fileBytes: fileBytes,
        fileName: fileName,
      );
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

  @override
  Future<void> deleteLesson(int lessonId) async =>
      _post('lesson_delete.php', {'lesson_id': lessonId});

  @override
  Future<void> deleteContent(int contentId) async =>
      _post('content_delete.php', {'content_id': contentId});

  @override
  Future<List<Assessment>> assessments(int classId) async {
    final data = await _get('assessments_list.php', {
      'class_id': classId,
      'per_page': 100,
    });
    return ((data['assessments'] ?? const []) as List)
        .map(
          (item) => Assessment.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
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
  }) async {
    final data = await _post('assessment_create.php', {
      'class_id': classId,
      'title': title,
      'description': description,
      'kind': kind,
      'duration_min': durationMin,
      'max_attempts': maxAttempts,
      'opens_at': ?opensAt,
      'closes_at': ?closesAt,
      'answer_release_policy': answerReleasePolicy,
    });
    return _asIntPub(data['id']);
  }

  @override
  Future<void> publishAssessment(int assessmentId) async =>
      _post('assessment_publish.php', {'assessment_id': assessmentId});

  @override
  Future<void> closeAssessment(int assessmentId) async =>
      _post('assessment_close.php', {'assessment_id': assessmentId});

  @override
  Future<void> releaseAssessmentAnswers(int assessmentId, bool release) async =>
      _post('assessment_release_answers.php', {
        'assessment_id': assessmentId,
        'release': release,
      });

  @override
  Future<void> deleteAssessment(int assessmentId) async =>
      _post('assessment_delete.php', {'assessment_id': assessmentId});

  @override
  Future<void> addQuestion(Map<String, dynamic> payload) async =>
      _post('question_add.php', payload);

  @override
  Future<void> deleteQuestion(int questionId) async =>
      _post('question_delete.php', {'question_id': questionId});

  AssessmentDetail _assessmentDetailFromResponse(dynamic data) {
    final assessment = Map<String, dynamic>.from(data['assessment'] as Map);
    return AssessmentDetail(
      id: _asIntPub(assessment['id']),
      classId: _asIntPub(assessment['class_id']),
      title: assessment['title'] ?? '',
      description: assessment['description'],
      kind: assessment['kind'] ?? 'quiz',
      status: assessment['status'] ?? 'published',
      durationMin: _asIntPub(assessment['duration_min']),
      maxAttempts: _asIntPub(assessment['max_attempts']) == 0
          ? 1
          : _asIntPub(assessment['max_attempts']),
      opensAt: assessment['opens_at'],
      closesAt: assessment['closes_at'],
      questions: ((data['questions'] ?? const []) as List)
          .map(
            (item) => Question.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }

  @override
  Future<AssessmentDetail> assessmentDetail(int id) async =>
      _assessmentDetailFromResponse(
        await _get('assessment_get.php', {'id': id}),
      );

  @override
  Future<StartedAttempt> startAttempt(int assessmentId) async {
    final data = await _post('attempt_start.php', {
      'assessment_id': assessmentId,
      'idempotency_key': _uuid.v4(),
    });
    final attempt = Map<String, dynamic>.from(data['attempt'] as Map);
    return StartedAttempt(
      attemptId: _asIntPub(attempt['id']),
      attemptNo: _asIntPub(attempt['attempt_no']),
      startedAt: attempt['started_at'],
      deadlineAt: attempt['deadline_at'],
      assessment: _assessmentDetailFromResponse(data),
    );
  }

  @override
  Future<AttemptResult> submitAttempt(
    int assessmentOrAttemptId,
    Map<int, dynamic> answers,
  ) async {
    final data = await _post('attempt_submit.php', {
      'attempt_id': assessmentOrAttemptId,
      'answers': answers.map((key, value) => MapEntry('$key', value)),
    }, true);
    return AttemptResult(
      attemptId: _asIntPub(data['attempt_id']),
      score: (data['score'] as num?)?.toDouble(),
      pendingEssay: data['pending_essay'] == true,
    );
  }

  @override
  Future<List<Attempt>> attempts(int assessmentId) async {
    final data = await _get('attempts_list.php', {
      'assessment_id': assessmentId,
      'per_page': 100,
    });
    return ((data['attempts'] ?? const []) as List)
        .map((item) => Attempt.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<AttemptDetail> attemptDetail(int id) async {
    final data = await _get('attempt_get.php', {'id': id});
    final attempt = Map<String, dynamic>.from(data['attempt'] as Map);
    return AttemptDetail(
      id: _asIntPub(attempt['id']),
      assessmentTitle: attempt['assessment_title'] ?? '',
      score: (attempt['score'] as num?)?.toDouble(),
      status: attempt['status'] ?? '',
      answersReleased: attempt['answers_released'] == true,
      deadlineAt: attempt['deadline_at'],
      answers: ((data['answers'] ?? const []) as List)
          .map(
            (item) =>
                AttemptAnswer.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }

  @override
  Future<void> gradeEssay(int answerId, int pointsEarned) async => _post(
    'essay_grade.php',
    {'answer_id': answerId, 'points_earned': pointsEarned},
  );

  @override
  Future<List<Homework>> homework(int classId) async {
    final data = await _get('homework_list.php', {
      'class_id': classId,
      'per_page': 100,
    });
    return ((data['homework'] ?? const []) as List)
        .map(
          (item) => Homework.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  Future<void> createHomework({
    required int classId,
    required String title,
    required String description,
    String? dueDate,
    bool allowLateSubmission = false,
    bool allowResubmit = true,
    String? resubmitUntil,
  }) async => _post('homework_create.php', {
    'class_id': classId,
    'title': title,
    'description': description,
    'due_date': ?dueDate,
    'allow_late_submission': allowLateSubmission,
    'allow_resubmit': allowResubmit,
    'resubmit_until': ?resubmitUntil,
  });

  @override
  Future<void> deleteHomework(int homeworkId) async =>
      _post('homework_delete.php', {'homework_id': homeworkId});

  @override
  Future<void> submitHomework({
    required int homeworkId,
    String? text,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    if (fileBytes != null && fileName != null) {
      await _postMultipart(
        'submission_submit.php',
        fields: {'homework_id': '$homeworkId', 'text': ?text},
        fileBytes: fileBytes,
        fileName: fileName,
      );
    } else {
      await _post('submission_submit.php', {
        'homework_id': homeworkId,
        'text': ?text,
      });
    }
  }

  @override
  Future<List<Submission>> submissions(int homeworkId) async {
    final data = await _get('submissions_list.php', {
      'homework_id': homeworkId,
      'per_page': 100,
    });
    return ((data['submissions'] ?? const []) as List)
        .map(
          (item) => Submission.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  Future<List<SubmissionVersion>> submissionHistory(int submissionId) async {
    final data = await _get('submission_history.php', {
      'submission_id': submissionId,
    });
    return ((data['versions'] ?? const []) as List)
        .map(
          (item) => SubmissionVersion.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> gradeSubmission(
    int submissionId,
    String grade,
    String feedback,
  ) async => _post('submission_grade.php', {
    'submission_id': submissionId,
    'grade': grade,
    'feedback': feedback,
  });

  @override
  Future<void> deleteSubmission(int submissionId) async =>
      _post('submission_delete.php', {'submission_id': submissionId});

  @override
  Future<List<QaThread>> qaThreads(int classId) async {
    final data = await _get('qa_list.php', {
      'class_id': classId,
      'per_page': 100,
    });
    return ((data['threads'] ?? const []) as List)
        .map(
          (item) => QaThread.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  Future<int> createThread(int classId, String title, String body) async {
    final data = await _post('qa_create.php', {
      'class_id': classId,
      'title': title,
      'body': body,
    });
    return _asIntPub(data['id']);
  }

  @override
  Future<void> replyThread(int threadId, String body) async =>
      _post('qa_reply.php', {'thread_id': threadId, 'body': body});

  @override
  Future<QaThreadDetail> qaThread(int id) async {
    final data = await _get('qa_thread.php', {'id': id});
    return QaThreadDetail(
      thread: QaThread.fromJson(
        Map<String, dynamic>.from(data['thread'] as Map),
      ),
      replies: ((data['replies'] ?? const []) as List)
          .map(
            (item) => QaReply.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }

  @override
  Future<DashboardData> dashboard() async {
    if (_userRole == null) await me();
    final teacher = _userRole == 'teacher';
    final data = await _get(
      teacher ? 'dashboard_teacher.php' : 'dashboard_student.php',
    );
    final list =
        (data[teacher ? 'recent_submissions' : 'upcoming_assessments']
            as List?) ??
        const [];
    return DashboardData(
      stats: Map<String, dynamic>.from(data['stats'] as Map),
      items: list
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }

  @override
  Future<LiveSession?> currentLive(int classId) async {
    final data = await _get('live_current.php', {'class_id': classId});
    if (data['session'] == null) return null;
    return LiveSession.fromJson(
      Map<String, dynamic>.from(data['session'] as Map),
    );
  }

  LiveSession _liveFrom(dynamic data) =>
      LiveSession.fromJson(Map<String, dynamic>.from(data['session'] as Map));

  @override
  Future<LiveSession> startLive(int classId) async =>
      _liveFrom(await _post('live_start.php', {'class_id': classId}));

  @override
  Future<LiveSession> joinLive(int sessionId) async =>
      _liveFrom(await _post('live_join.php', {'session_id': sessionId}));

  @override
  Future<void> endLive(int sessionId) async =>
      _post('live_end.php', {'session_id': sessionId});

  @override
  Future<DemoAccess> createDemo() async {
    final data = await _post('demo_start.php');
    return DemoAccess(
      demoId: data['demo_id'] as String,
      accessKey: data['access_key'] as String,
      expiresAt: data['expires_at'] as String?,
    );
  }

  @override
  Future<User> loginDemo(DemoAccess access, String role) async =>
      _acceptSession(
        await _post('demo_login.php', {
          'demo_id': access.demoId,
          'access_key': access.accessKey,
          'role': role,
        }),
      );
}

int _asIntPub(dynamic value) =>
    value is int ? value : int.tryParse('${value ?? ''}') ?? 0;
