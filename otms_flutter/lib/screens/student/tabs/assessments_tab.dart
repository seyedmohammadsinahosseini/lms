import 'package:flutter/material.dart' hide Badge;

import '../../../models/models.dart';
import '../../../services/api_client.dart';
import '../../shared/widgets.dart';
import '../take_assessment.dart';
import '../attempt_result.dart';

/// Lists a class's assessments with the student's own attempt status.
class AssessmentsTab extends StatefulWidget {
  final int classId;
  const AssessmentsTab({super.key, required this.classId});
  @override
  State<AssessmentsTab> createState() => _AssessmentsTabState();
}

class _AssessmentsTabState extends State<AssessmentsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Assessment>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.assessments(widget.classId);
  }

  void _reload() =>
      setState(() => _future = ApiClient.instance.assessments(widget.classId));

  Color _kindColor(String kind) {
    switch (kind) {
      case 'exam':
        return Colors.redAccent;
      case 'test':
        return Colors.orange;
      default:
        return Colors.teal;
    }
  }

  Future<void> _openAttempt(Assessment a) async {
    final attempt = a.attempt;
    if (attempt != null) {
      // Already attempted -> show result.
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AttemptResultScreen(attemptId: attempt.id),
      ));
    } else {
      final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => TakeAssessment(assessmentId: a.id, title: a.title),
      ));
      if (done == true) _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Assessment>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return ErrorRetry(error: snap.error!, onRetry: _reload);
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.quiz_outlined,
            title: 'No assessments yet',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final a = items[i];
            final attempt = a.attempt;
            return Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(a.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Badge(a.kind.toUpperCase(), color: _kindColor(a.kind)),
                      Badge('${a.questionCount} Qs',
                          icon: Icons.help_outline),
                      if (a.durationMin > 0)
                        Badge('${a.durationMin} min',
                            icon: Icons.timer_outlined),
                      if (attempt != null)
                        _attemptBadge(attempt),
                    ],
                  ),
                ),
                trailing: attempt == null
                    ? FilledButton(
                        onPressed: () => _openAttempt(a),
                        child: const Text('Start'),
                      )
                    : TextButton(
                        onPressed: () => _openAttempt(a),
                        child: const Text('View'),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _attemptBadge(AttemptSummary s) {
    if (s.status == 'completed') {
      return const Badge('Awaiting grade',
          icon: Icons.hourglass_bottom, color: Colors.blueGrey);
    }
    final score = s.score?.toStringAsFixed(0) ?? '--';
    return Badge('Scored $score%',
        icon: Icons.check_circle_outline, color: Colors.green);
  }
}
