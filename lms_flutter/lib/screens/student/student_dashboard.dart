import 'package:flutter/material.dart' hide Badge;

import '../../models/models.dart';
import '../../services/api.dart';
import '../shared/live_demo.dart';
import '../shared/sidebar.dart' hide hexColor;
import '../shared/widgets.dart';
import 'join_teacher_screen.dart';
import 'tabs/assessments_tab.dart';
import 'tabs/homework_tab.dart';
import 'tabs/lessons_tab.dart';
import 'tabs/qa_tab.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  late Future<List<ClassModel>> _classesFuture;
  late Future<DashboardData> _dashboardFuture;
  List<ClassModel> _classes = const [];
  int? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  void _reloadAll() {
    _classesFuture = Api.instance.classes().then((classes) {
      _classes = classes;
      if (_selectedClassId != null &&
          !classes.any((item) => item.id == _selectedClassId)) {
        _selectedClassId = null;
      }
      return classes;
    });
    _dashboardFuture = Api.instance.dashboard();
  }

  void _refresh() => setState(_reloadAll);

  Future<void> _joinTeacher() async {
    final joined = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const JoinTeacherScreen()));
    if (joined == true && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      isTeacher: false,
      selectedClassId: _selectedClassId,
      onDashboardPressed: () => setState(() => _selectedClassId = null),
      onClassesPressed: () => setState(() => _selectedClassId = null),
      child: _selectedClassId == null
          ? _overview()
          : _classDetail(_selectedClassId!),
    );
  }

  Widget _overview() => Scaffold(
    appBar: AppBar(
      title: const Text('Student dashboard'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await Future.wait([_classesFuture, _dashboardFuture]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<DashboardData>(
            future: _dashboardFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 132, child: LoadingView());
              }
              if (snapshot.hasError) {
                return ErrorRetry(error: snapshot.error!, onRetry: _refresh);
              }
              return _statistics(snapshot.data!);
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('My classes', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              FilledButton.icon(
                onPressed: _joinTeacher,
                icon: const Icon(Icons.add),
                label: const Text('Join'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<ClassModel>>(
            future: _classesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 220, child: LoadingView());
              }
              if (snapshot.hasError) {
                return ErrorRetry(error: snapshot.error!, onRetry: _refresh);
              }
              final classes = snapshot.data ?? const [];
              if (classes.isEmpty) {
                return EmptyState(
                  icon: Icons.class_outlined,
                  title: 'No classes yet',
                  subtitle: 'Use your teacher’s code to join a class.',
                  action: FilledButton(
                    onPressed: _joinTeacher,
                    child: const Text('Join a teacher'),
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 3
                      : constraints.maxWidth >= 600
                      ? 2
                      : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: columns == 1 ? 2.4 : 1.65,
                    ),
                    itemCount: classes.length,
                    itemBuilder: (_, index) => _classCard(classes[index]),
                  );
                },
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _statistics(DashboardData dashboard) {
    final stats = dashboard.stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overview', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _stat(
              'Classes',
              '${stats['class_count'] ?? 0}',
              Icons.class_outlined,
            ),
            _stat(
              'Available assessments',
              '${stats['available_assessments'] ?? 0}',
              Icons.quiz_outlined,
            ),
            _stat(
              'Pending homework',
              '${stats['pending_homework'] ?? 0}',
              Icons.assignment_outlined,
            ),
            _stat(
              'Average score',
              stats['average_score'] == null
                  ? '—'
                  : '${stats['average_score']}%',
              Icons.insights_outlined,
            ),
          ],
        ),
        if (dashboard.items.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Upcoming assessments',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...dashboard.items.map(
            (item) => Card(
              child: ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: Text(item['title']?.toString() ?? ''),
                subtitle: Text(
                  '${item['class_name'] ?? ''}${item['closes_at'] == null ? '' : ' · closes ${item['closes_at']}'}',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon) => SizedBox(
    width: 190,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _classCard(ClassModel classModel) {
    final color = hexColor(classModel.color);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selectedClassId = classModel.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: .14),
                child: Icon(Icons.menu_book_outlined, color: color),
              ),
              const Spacer(),
              Text(
                classModel.name,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (classModel.description?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  classModel.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (classModel.teacherName != null) ...[
                const SizedBox(height: 8),
                Text('Teacher: ${classModel.teacherName}'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _classDetail(int classId) {
    final matches = _classes.where((item) => item.id == classId);
    if (matches.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedClassId = null);
      });
      return const Scaffold(body: LoadingView());
    }
    final classModel = matches.first;
    final color = hexColor(classModel.color);
    return DefaultTabController(
      key: ValueKey(classId),
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(classModel.name),
          leading: IconButton(
            tooltip: 'Dashboard',
            onPressed: () => setState(() => _selectedClassId = null),
            icon: const Icon(Icons.arrow_back),
          ),
          backgroundColor: color.withValues(alpha: .12),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Lessons'),
              Tab(text: 'Assessments'),
              Tab(text: 'Homework'),
              Tab(text: 'Q&A'),
              Tab(text: 'Live'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            LessonsTab(key: ValueKey('lessons-$classId'), classId: classId),
            AssessmentsTab(
              key: ValueKey('assessments-$classId'),
              classId: classId,
            ),
            HomeworkTab(key: ValueKey('homework-$classId'), classId: classId),
            QaTab(key: ValueKey('qa-$classId'), classId: classId),
            _LiveTab(classId: classId, className: classModel.name),
          ],
        ),
      ),
    );
  }
}

class _LiveTab extends StatelessWidget {
  final int classId;
  final String className;
  const _LiveTab({required this.classId, required this.className});

  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              LiveDemoScreen(classId: classId, className: className),
        ),
      ),
      icon: const Icon(Icons.videocam_outlined),
      label: const Text('Open live classroom'),
    ),
  );
}
