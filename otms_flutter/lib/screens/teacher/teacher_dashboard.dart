import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../state/auth_provider.dart';
import '../shared/widgets.dart';
import '../shared/sidebar.dart';
import 'tabs/t_assessments_tab.dart';
import 'tabs/t_homework_tab.dart';
import 'tabs/t_lessons_tab.dart';
import 'tabs/t_students_tab.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard>
    with SingleTickerProviderStateMixin {
  int? _selectedClassId;
  late TabController _tabController;
  List<ClassModel> _classes = [];
  bool _loadingClasses = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadClasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await Api.instance.classes();
      if (mounted) {
        setState(() {
          _classes = classes;
          _loadingClasses = false;
          if (_classes.isNotEmpty && _selectedClassId == null) {
            _selectedClassId = _classes.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingClasses = false);
      }
    }
  }

  void _onClassSelected(int classId) {
    setState(() => _selectedClassId = classId);
  }

  void _onCreateClass() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateClassSheet(),
    );
    if (created == true) {
      await _loadClasses();
    }
  }

  void _onDashboardPressed() {
    setState(() => _selectedClassId = null);
  }

  void _onClassesPressed() {
    // Show classes overview in main content area
    setState(() => _selectedClassId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
body: Sidebar(
  isTeacher: true,
  selectedClassId: _selectedClassId,
  onClassSelected: _onClassSelected,
  onDashboardPressed: _onDashboardPressed,
  onClassesPressed: _onClassesPressed,
  onCreateClassPressed: _onCreateClass,
  child: _selectedClassId == null
      ? _buildDashboardOverview()
      : _buildClassDetail(_selectedClassId!),
),
    );
  }

  Widget _buildDashboardOverview() {
    final auth = context.watch<AuthProvider>();
    return RefreshIndicator(
      onRefresh: _loadClasses,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      Text(
                        auth.user?.fullName ?? 'Teacher',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _onCreateClass,
                  icon: const Icon(Icons.add),
                  label: const Text('New Class'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Stats cards
            _buildStatsGrid(),
            const SizedBox(height: 32),

            // Upcoming assessments
            _buildUpcomingAssessments(),
            const SizedBox(height: 24),

            // Top students
            _buildTopStudents(),
            const SizedBox(height: 24),

            // Recent activity / Classes overview
            _buildClassesOverview(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : 
                               constraints.maxWidth > 600 ? 2 : 1;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            _buildStatCard(
              'Total Students',
              _getTotalStudents().toString(),
              Icons.people_outline,
              Colors.blue,
            ),
            _buildStatCard(
              'Active Classes',
              _classes.length.toString(),
              Icons.class_outlined,
              Colors.green,
            ),
            _buildStatCard(
              'Total Assessments',
              _getTotalAssessments().toString(),
              Icons.quiz_outlined,
              Colors.orange,
            ),
            _buildStatCard(
              'Pending Grading',
              _getPendingGrading().toString(),
              Icons.pending_outlined,
              Colors.red,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAssessments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Upcoming Assessments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to assessments view
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildUpcomingItem(
                  'Mathematics - Fractions Quiz',
                  'Tomorrow, 10:00 AM',
                  '15 min',
                  Colors.blue,
                ),
                _buildUpcomingItem(
                  'Physics - Mechanics Test',
                  'In 3 days, 2:00 PM',
                  '45 min',
                  Colors.green,
                ),
                _buildUpcomingItem(
                  'Chemistry - Periodic Table Quiz',
                  'Next Week, 9:00 AM',
                  '20 min',
                  Colors.orange,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingItem(String title, String date, String duration, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              duration,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStudents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Top Performing Students',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _buildStudentRow(1, 'Alice Johnson', 'Mathematics', 98.5, Colors.amber),
              _buildStudentRow(2, 'Bob Smith', 'Physics', 95.2, Colors.grey),
              _buildStudentRow(3, 'Carol Williams', 'Chemistry', 93.8, Colors.brown),
              _buildStudentRow(4, 'David Brown', 'Mathematics', 91.0, Colors.blue),
              _buildStudentRow(5, 'Emma Davis', 'Physics', 89.5, Colors.green),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentRow(int rank, String name, String subject, double score, Color medalColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: medalColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subject,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${score.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Classes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: _onCreateClass,
              child: const Text('Create New'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingClasses)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_classes.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.class_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No classes yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first class to get started',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _onCreateClass,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Class'),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 :
                               MediaQuery.of(context).size.width > 600 ? 2 : 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _classes.length,
            itemBuilder: (_, i) => _buildClassCard(_classes[i]),
          ),
      ],
    );
  }

  Widget _buildClassCard(ClassModel cls) {
    final colorInt = hexColor(cls.color);
    final color = Color(colorInt);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _onClassSelected(cls.id),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.menu_book_rounded, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cls.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (cls.description != null && cls.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  cls.description!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${cls.studentCount ?? 0} students',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Open',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassDetail(int classId) {
    final cls = _classes.firstWhere((c) => c.id == classId);
    final colorInt = hexColor(cls.color);
    final color = Color(colorInt);

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(cls.name),
          backgroundColor: color.withValues(alpha: 0.12),
          bottom: TabBar(
            isScrollable: true,
            tabs: const [
              Tab(text: 'Lessons'),
              Tab(text: 'Assessments'),
              Tab(text: 'Homework'),
              Tab(text: 'Q&A'),
              Tab(text: 'Students'),
              Tab(text: 'Live'),
            ],
            labelStyle: const TextStyle(fontSize: 13),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TabBarView(
            children: [
              TLessonsTab(classId: classId),
              TAssessmentsTab(classId: classId),
              THomeworkTab(classId: classId),
              _buildQaTab(classId),
              TStudentsTab(classId: classId),
              _LiveTab(className: cls.name),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQaTab(int classId) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Q&A Forum',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Student questions will appear here',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  int _getTotalStudents() {
    return _classes.fold(0, (sum, cls) => sum + (cls.studentCount ?? 0));
  }

  int _getTotalAssessments() {
    // This would require an API call to get total assessments across all classes
    // For now, return a placeholder
    return _classes.length * 3;
  }

  int _getPendingGrading() {
    // Placeholder
    return _classes.length;
  }
}

class _CreateClassSheet extends StatefulWidget {
  const _CreateClassSheet();
  @override
  State<_CreateClassSheet> createState() => _CreateClassSheetState();
}

class _CreateClassSheetState extends State<_CreateClassSheet> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String _color = '#6366F1';
  bool _busy = false;

  static const _palette = [
    '#6366F1', '#14B8A6', '#F59E0B', '#EF4444', '#8B5CF6', '#10B981',
  ];

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showError(context, 'Give the class a name.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.instance
          .createClass(_name.text.trim(), _desc.text.trim(), _color);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New class',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name (e.g. Physics)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Color'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: _palette.map((c) {
              final selected = c == _color;
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(hexColor(c)),
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create class'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveTab extends StatelessWidget {
  final String className;
  const _LiveTab({required this.className});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.podcasts,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Host a live session',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a demo live classroom for $className',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.videocam),
            label: const Text('Go live (demo)'),
          ),
        ],
      ),
    );
  }
}

int hexColor(String hex) {
  hex = hex.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return int.parse(hex, radix: 16);
}