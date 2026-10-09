import '../models/models.dart';
import '../services/lms_api.dart';

/// Deterministic, in-memory data used only by `main_showcase.dart` when the
/// repository's product screenshots are generated. Production entrypoints never
/// import or instantiate this class.
class ShowcaseApi implements LmsApi {
  ShowcaseApi(this.role);

  final String role;

  @override
  void Function()? onUnauthorized;

  @override
  Future<void> loadToken() async {}

  @override
  Future<User?> me() async {
    if (role == 'anonymous') return null;
    return User(
      id: role == 'teacher' ? 1 : 2,
      fullName: role == 'teacher' ? 'Dr. Maya Chen' : 'Alex Morgan',
      email: '$role@demo.invalid',
      role: role,
    );
  }

  @override
  Future<void> logout() async {}

  @override
  String fileUrl(String relativePath) => relativePath;

  @override
  Future<String?> getCode() async => 'LMS-7K2P';

  @override
  Future<List<ClassModel>> classes() async => [
    ClassModel(
      id: 1,
      name: 'Calculus Foundations',
      description: 'Limits, derivatives, and real-world applications',
      color: '#6366F1',
      teacherName: 'Dr. Maya Chen',
      studentCount: 28,
    ),
    ClassModel(
      id: 2,
      name: 'Physics Lab',
      description: 'Mechanics experiments and collaborative reports',
      color: '#0D9488',
      teacherName: 'Dr. Maya Chen',
      studentCount: 24,
    ),
    ClassModel(
      id: 3,
      name: 'Academic Writing',
      description: 'Evidence, structure, and peer-reviewed arguments',
      color: '#EA580C',
      teacherName: 'Dr. Maya Chen',
      studentCount: 31,
    ),
  ];

  @override
  Future<DashboardData> dashboard() async {
    if (role == 'teacher') {
      return DashboardData(
        stats: {
          'class_count': 3,
          'student_count': 83,
          'active_assessments': 5,
          'pending_grading': 12,
        },
        items: [
          {
            'student_name': 'Alex Morgan',
            'homework_title': 'Derivative practice',
            'class_name': 'Calculus Foundations',
            'submitted_at': 'Today, 09:42',
          },
          {
            'student_name': 'Sara Ahmed',
            'homework_title': 'Lab report: motion',
            'class_name': 'Physics Lab',
            'submitted_at': 'Yesterday, 18:10',
          },
        ],
      );
    }
    return DashboardData(
      stats: {
        'class_count': 3,
        'available_assessments': 4,
        'pending_homework': 2,
        'average_score': 91,
      },
      items: [
        {
          'title': 'Limits and continuity',
          'class_name': 'Calculus Foundations',
          'closes_at': 'Oct 14, 2026 · 18:00',
        },
        {
          'title': 'Newton’s laws',
          'class_name': 'Physics Lab',
          'closes_at': 'Oct 17, 2026 · 12:00',
        },
      ],
    );
  }

  @override
  Future<List<Lesson>> lessons(int classId) async => [
    Lesson(id: 1, title: 'Understanding limits', position: 0),
    Lesson(id: 2, title: 'The derivative as a rate of change', position: 1),
    Lesson(id: 3, title: 'Applications and optimization', position: 2),
  ];

  @override
  Future<List<Content>> contents(int lessonId) async => [
    Content(
      id: 1,
      type: 'note',
      title: 'Key concepts and worked examples',
      body: 'A concise summary of the lesson.',
    ),
    Content(
      id: 2,
      type: 'video',
      title: 'Visual explanation',
      url: 'https://example.invalid/video',
    ),
    Content(
      id: 3,
      type: 'booklet',
      title: 'Practice booklet',
      filePath: 'showcase/practice.pdf',
    ),
  ];

  @override
  Future<List<Assessment>> assessments(int classId) async => [
    Assessment(
      id: 1,
      title: 'Limits and continuity',
      description: 'Six question types with timed submission.',
      kind: 'quiz',
      status: 'published',
      durationMin: 20,
      maxAttempts: 2,
      questionCount: 8,
      closesAt: '2026-10-14 18:00:00',
    ),
    Assessment(
      id: 2,
      title: 'Midterm examination',
      description: 'Versioned draft ready for review.',
      kind: 'exam',
      status: 'draft',
      durationMin: 60,
      maxAttempts: 1,
      questionCount: 12,
    ),
  ];

  @override
  Future<List<Homework>> homework(int classId) async => [
    Homework(
      id: 1,
      title: 'Derivative practice',
      description: 'Solve the attached set and explain each method.',
      dueAt: '2026-10-15 23:59:00',
      allowLateSubmission: true,
      allowResubmit: true,
      submissionCount: 21,
      pendingCount: 7,
    ),
  ];

  @override
  Future<List<QaThread>> qaThreads(int classId) async => [
    QaThread(
      id: 1,
      title: 'Why does the limit exist here?',
      body: 'I understand the graph but not the algebraic proof.',
      authorName: 'Alex Morgan',
      replyCount: 3,
      createdAt: '2026-10-08 14:30:00',
    ),
  ];

  @override
  Future<LiveSession?> currentLive(int classId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
