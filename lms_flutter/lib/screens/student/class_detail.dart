import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../shared/live_demo.dart';
import '../shared/widgets.dart';
import 'tabs/assessments_tab.dart';
import 'tabs/homework_tab.dart';
import 'tabs/lessons_tab.dart';
import 'tabs/qa_tab.dart';

/// Student view of one class: Lessons, Assessments, Homework, Q&A, Live.
class ClassDetail extends StatelessWidget {
  final ClassModel cls;
  const ClassDetail({super.key, required this.cls});

  @override
  Widget build(BuildContext context) {
    final color = hexColor(cls.color);
    return DefaultTabController(
      length: 5,
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
              Tab(text: 'Live'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            LessonsTab(classId: cls.id),
            AssessmentsTab(classId: cls.id),
            HomeworkTab(classId: cls.id),
            QaTab(classId: cls.id),
            _LiveTab(classId: cls.id, className: cls.name),
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
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.podcasts,
      title: 'Live session',
      subtitle: 'Join the current protected live classroom.',
      action: FilledButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                LiveDemoScreen(classId: classId, className: className),
          ),
        ),
        icon: const Icon(Icons.videocam),
        label: const Text('Open live classroom'),
      ),
    );
  }
}
