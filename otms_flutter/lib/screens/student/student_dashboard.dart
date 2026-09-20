import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../state/auth_provider.dart';
import '../shared/sidebar.dart';
import 'tabs/assessments_tab.dart';
import 'tabs/homework_tab.dart';
import 'tabs/lessons_tab.dart';
import 'tabs/qa_tab.dart';
import '../shared/live_demo.dart';
import 'join_teacher_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  int? _selectedClassId;
  late TabController _tabController;
  List<ClassModel> _classes = [];
  bool _loadingClasses = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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

  void _onJoinClass() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const JoinTeacherScreen()),
    );
    if (changed == true) {
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
          isTeacher: false,
          selectedClassId: _selectedClassId,
          onClassSelected: _onClassSelected,
          onDashboardPressed: _onDashboardPressed,
          onClassesPressed: _onClassesPressed,
          onCreateClassPressed: null,
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
                        auth.user?.fullName ?? 'Student',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _onJoinClass,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Join Class'),
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

            // Performance overview
            _buildPerformanceOverview(),
            const SizedBox(height: 24),

            // Classes overview
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
              'Enrolled Classes',
              _classes.length.toString(),
              Icons.class_outlined,
              Colors.blue,
            ),
            _buildStatCard(
              'Completed Assessments',
              _getCompletedAssessments().toString(),
              Icons.check_circle_outline,
              Colors.green,
            ),
            _buildStatCard(
              'Average Score',
              '${_getAverageScore().toStringAsFixed(1)}%',
              Icons.leaderboard_outlined,
              Colors.orange,
            ),
            _buildStatCard(
              'Pending Homework',
              _getPendingHomework().toString(),
              Icons.assignment_outlined,
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
              onPressed: () {},
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
                  'Not started',
                  Colors.blue,
                ),
                _buildUpcomingItem(
                  'Physics - Mechanics Test',
                  'In 3 days, 2:00 PM',
                  '45 min',
                  'Not started',
                  Colors.green,
                ),
                _buildUpcomingItem(
                  'Chemistry - Periodic Table Quiz',
                  'Next Week, 9:00 AM',
                  '20 min',
                  'Not started',
                  Colors.orange,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingItem(String title, String date, String duration, String status, Color color) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  duration,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Performance Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Details'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Overall progress ring
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: _getAverageScore() / 100,
                              strokeWidth: 8,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getAverageScore() >= 70 ? Colors.green :
                                _getAverageScore() >= 50 ? Colors.orange : Colors.red,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_getAverageScore().toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Average',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProgressBar('Mathematics', 85, Colors.blue),
                          const SizedBox(height: 12),
                          _buildProgressBar('Physics', 72, Colors.green),
                          const SizedBox(height: 12),
                          _buildProgressBar('Chemistry', 68, Colors.orange),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniStat('Assessments\nTaken', _getCompletedAssessments().toString()),
                    _buildMiniStat('Avg. Time\nPer Test', '12 min'),
                    _buildMiniStat('Best\nStreak', '5 days'),
                    _buildMiniStat('Rank', '#12'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(String subject, int score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              subject,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$score%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: score / 100,
          backgroundColor: color.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
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
              onPressed: _onJoinClass,
              child: const Text('Join New'),
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
                    Icons.school_outlined,
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
                    'Join a class using a teacher\'s code',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _onJoinClass,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Join Class'),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cls.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (cls.teacherName != null)
                          Text(
                            cls.teacherName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                      ],
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
                Text(
                  cls.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Continue',
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
      length: 5,
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
              LessonsTab(classId: classId),
              AssessmentsTab(classId: classId),
              HomeworkTab(classId: classId),
              QaTab(classId: classId),
              _LiveTab(className: cls.name),
            ],
          ),
        ),
      ),
    );
  }

  int _getCompletedAssessments() {
    // Placeholder - would need API call
    return _classes.length * 2;
  }

  double _getAverageScore() {
    // Placeholder
    return 78.5;
  }

  int _getPendingHomework() {
    // Placeholder
    return _classes.length;
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
            'Live session',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join a demo live classroom for $className',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LiveDemoScreen(className: className),
              ),
            ),
            icon: const Icon(Icons.videocam),
            label: const Text('Join live (demo)'),
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