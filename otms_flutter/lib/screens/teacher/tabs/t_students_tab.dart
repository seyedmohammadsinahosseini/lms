import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../../services/api_client.dart';
import '../../shared/widgets.dart';

/// Roster of students enrolled in a class.
class TStudentsTab extends StatefulWidget {
  final int classId;
  const TStudentsTab({super.key, required this.classId});
  @override
  State<TStudentsTab> createState() => _TStudentsTabState();
}

class _TStudentsTabState extends State<TStudentsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<StudentRow>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.classStudents(widget.classId);
  }

  void _reload() => setState(
      () => _future = ApiClient.instance.classStudents(widget.classId));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<StudentRow>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return ErrorRetry(error: snap.error!, onRetry: _reload);
        }
        final students = snap.data ?? [];
        if (students.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline,
            title: 'No students yet',
            subtitle: 'Share your join code so students can enroll.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: students.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final s = students[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(s.fullName.isNotEmpty
                      ? s.fullName[0].toUpperCase()
                      : '?'),
                ),
                title: Text(s.fullName),
                subtitle: Text(s.email),
              ),
            );
          },
        );
      },
    );
  }
}
