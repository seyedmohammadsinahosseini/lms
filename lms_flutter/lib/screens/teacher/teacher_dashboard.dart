import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../shared/live_demo.dart';
import '../shared/sidebar.dart' hide hexColor;
import '../shared/widgets.dart';
import '../student/tabs/qa_tab.dart';
import 'tabs/t_assessments_tab.dart';
import 'tabs/t_homework_tab.dart';
import 'tabs/t_lessons_tab.dart';
import 'tabs/t_students_tab.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  late Future<List<ClassModel>> _classesFuture;
  late Future<DashboardData> _dashboardFuture;
  late Future<String> _codeFuture;
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
    _codeFuture = Api.instance.getCode().then((code) => code ?? '');
  }

  void _refresh() => setState(_reloadAll);

  Future<void> _createClass() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateClassSheet(),
    );
    if (created == true && mounted) _refresh();
  }

  Future<void> _deleteClass(ClassModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete class?'),
        content: Text(
          '“${item.name}” and all of its lessons, assessments, homework, Q&A, and enrollment records will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Api.instance.deleteClass(item.id);
      if (!mounted) return;
      if (_selectedClassId == item.id) _selectedClassId = null;
      showOk(context, 'Class deleted.');
      _refresh();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _regenerateCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate a new teacher code?'),
        content: const Text(
          'Your current code will stop working. Existing student enrollments are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final code = await Api.instance.regenerateCode();
      if (!mounted) return;
      setState(() => _codeFuture = Future.value(code));
      showOk(context, 'New teacher code generated.');
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      isTeacher: true,
      selectedClassId: _selectedClassId,
      onDashboardPressed: () => setState(() => _selectedClassId = null),
      onClassesPressed: () => setState(() => _selectedClassId = null),
      onCreateClassPressed: _createClass,
      child: _selectedClassId == null
          ? _overview()
          : _classDetail(_selectedClassId!),
    );
  }

  Widget _overview() => Scaffold(
    appBar: AppBar(
      title: const Text('Teacher dashboard'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'create-class',
      onPressed: _createClass,
      icon: const Icon(Icons.add),
      label: const Text('New class'),
    ),
    body: RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await Future.wait([_classesFuture, _dashboardFuture, _codeFuture]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          FutureBuilder<String>(
            future: _codeFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 92, child: LoadingView());
              }
              if (snapshot.hasError) {
                return ErrorRetry(error: snapshot.error!, onRetry: _refresh);
              }
              return _teacherCode(snapshot.data ?? '');
            },
          ),
          const SizedBox(height: 20),
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
              Text('Classes', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton.icon(
                onPressed: _createClass,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
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
                  subtitle: 'Create a class, then share your teacher code.',
                  action: FilledButton(
                    onPressed: _createClass,
                    child: const Text('Create first class'),
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
                      childAspectRatio: columns == 1 ? 2.5 : 1.65,
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

  Widget _teacherCode(String code) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.vpn_key_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Teacher code'),
                SelectableText(
                  code,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            onPressed: code.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (mounted) showOk(context, 'Teacher code copied.');
                  },
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: 'Generate new code',
            onPressed: _regenerateCode,
            icon: const Icon(Icons.autorenew),
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
              'Students',
              '${stats['student_count'] ?? 0}',
              Icons.people_outline,
            ),
            _stat(
              'Active assessments',
              '${stats['active_assessments'] ?? 0}',
              Icons.quiz_outlined,
            ),
            _stat(
              'Pending grading',
              '${stats['pending_grading'] ?? 0}',
              Icons.rate_review_outlined,
            ),
          ],
        ),
        if (dashboard.items.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Recent homework submissions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...dashboard.items.map(
            (item) => Card(
              child: ListTile(
                leading: const Icon(Icons.assignment_turned_in_outlined),
                title: Text(item['student_name']?.toString() ?? ''),
                subtitle: Text(
                  '${item['homework_title'] ?? ''} · ${item['class_name'] ?? ''}',
                ),
                trailing: Text(item['submitted_at']?.toString() ?? ''),
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

  Widget _classCard(ClassModel item) {
    final color = hexColor(item.color);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selectedClassId = item.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .14),
                    child: Icon(Icons.school_outlined, color: color),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Class actions',
                    onSelected: (value) {
                      if (value == 'delete') _deleteClass(item);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete class'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(
                item.name,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.description?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  item.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Text('${item.studentCount} enrolled student(s)'),
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
    final item = matches.first;
    final color = hexColor(item.color);
    return DefaultTabController(
      key: ValueKey(classId),
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(item.name),
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
              Tab(text: 'Students'),
              Tab(text: 'Q&A'),
              Tab(text: 'Live'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TLessonsTab(key: ValueKey('lessons-$classId'), classId: classId),
            TAssessmentsTab(
              key: ValueKey('assessments-$classId'),
              classId: classId,
            ),
            THomeworkTab(key: ValueKey('homework-$classId'), classId: classId),
            TStudentsTab(key: ValueKey('students-$classId'), classId: classId),
            QaTab(
              key: ValueKey('qa-$classId'),
              classId: classId,
              canAsk: false,
            ),
            _LiveTab(classId: classId, className: item.name),
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
          builder: (_) => LiveDemoScreen(
            classId: classId,
            className: className,
            asHost: true,
          ),
        ),
      ),
      icon: const Icon(Icons.video_call_outlined),
      label: const Text('Manage live classroom'),
    ),
  );
}

class _CreateClassSheet extends StatefulWidget {
  const _CreateClassSheet();

  @override
  State<_CreateClassSheet> createState() => _CreateClassSheetState();
}

class _CreateClassSheetState extends State<_CreateClassSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _color = '#2563EB';
  bool _busy = false;

  static const _colors = [
    '#2563EB',
    '#7C3AED',
    '#059669',
    '#DC2626',
    '#D97706',
    '#0891B2',
  ];

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showError(context, 'Enter a class name.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.instance.createClass(
        _name.text.trim(),
        _description.text.trim(),
        _color,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create class', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Class name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 16),
          const Text('Color'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: _colors
                .map(
                  (value) => ChoiceChip(
                    label: const SizedBox(width: 24, height: 18),
                    selected: _color == value,
                    avatar: CircleAvatar(backgroundColor: hexColor(value)),
                    onSelected: (_) => setState(() => _color = value),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create class'),
            ),
          ),
        ],
      ),
    ),
  );
}
