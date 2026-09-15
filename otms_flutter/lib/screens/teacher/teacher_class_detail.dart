import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../shared/live_demo.dart';
import '../shared/widgets.dart';
import '../student/tabs/qa_tab.dart';
import 'tabs/t_assessments_tab.dart';
import 'tabs/t_homework_tab.dart';
import 'tabs/t_lessons_tab.dart';
import 'tabs/t_students_tab.dart';

/// Teacher view of one class: authoring lessons/assessments/homework,
/// reviewing submissions, answering Q&A, seeing the roster, hosting live.
class TeacherClassDetail extends StatelessWidget {
  final ClassModel cls;
  const TeacherClassDetail({super.key, required this.cls});

  @override
  Widget build(BuildContext context) {
    final color = hexColor(cls.color);
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(cls.name),
          backgroundColor: color.withValues(alpha: 0.12),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Lessons'),
              Tab(text: 'Assessments'),
              Tab(text: 'Homework'),
              Tab(text: 'Q&A'),
              Tab(text: 'Students'),
              Tab(text: 'Live'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TLessonsTab(classId: cls.id),
            TAssessmentsTab(classId: cls.id),
            THomeworkTab(classId: cls.id),
            QaTab(classId: cls.id),
            TStudentsTab(classId: cls.id),
            _LiveTab(className: cls.name),
          ],
        ),
      ),
    );
  }
}

class _LiveTab extends StatelessWidget {
  final String className;
  const _LiveTab({required this.className});
  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.podcasts,
      title: 'Host a live session',
      subtitle: 'Start a demo live classroom for this subject.',
      action: FilledButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                LiveDemoScreen(className: className, asHost: true),
          ),
        ),
        icon: const Icon(Icons.videocam),
        label: const Text('Go live (demo)'),
      ),
    );
  }
}
