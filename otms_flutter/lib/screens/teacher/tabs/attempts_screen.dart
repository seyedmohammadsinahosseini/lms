import 'package:flutter/material.dart' hide Badge;

import '../../../models/models.dart';
import '../../../services/api.dart';
import '../../shared/widgets.dart' show LoadingView, ErrorRetry, EmptyState, Badge;
import 'essay_grading_screen.dart';
import '../../student/attempt_result.dart';

/// Teacher view of all attempts for an assessment.
/// Allows drilling into each attempt for review and essay grading.
class AttemptsScreen extends StatefulWidget {
  final int assessmentId;
  final String title;
  const AttemptsScreen({
    super.key,
    required this.assessmentId,
    required this.title,
  });
  @override
  State<AttemptsScreen> createState() => _AttemptsScreenState();
}

class _AttemptsScreenState extends State<AttemptsScreen> {
  late Future<List<Attempt>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.instance.attempts(widget.assessmentId);
  }

  void _reload() =>
      setState(() => _future = Api.instance.attempts(widget.assessmentId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<Attempt>>(
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
              icon: Icons.assignment_turned_in_outlined,
              title: 'No attempts yet',
              subtitle: 'Students have not started this assessment.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _AttemptCard(
              attempt: items[i],
              onTap: () {
                // Check if attempt has essay questions needing grading
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AttemptResultScreen(attemptId: items[i].id),
                )).then((_) => _reload());
              },
              onGradeEssays: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EssayGradingScreen(attemptId: items[i].id),
                )).then((_) => _reload());
              },
            ),
          );
        },
      ),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  final Attempt attempt;
  final VoidCallback onTap;
  final VoidCallback onGradeEssays;

  const _AttemptCard({
    required this.attempt,
    required this.onTap,
    required this.onGradeEssays,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasScore = attempt.score != null;
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Text(attempt.studentName.isNotEmpty
              ? attempt.studentName[0].toUpperCase()
              : '?'),
        ),
        title: Text(attempt.studentName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Badge(attempt.status,
                    icon: attempt.status == 'completed'
                        ? Icons.check_circle
                        : Icons.hourglass_bottom,
                    color: attempt.status == 'completed'
                        ? Colors.green
                        : Colors.orange),
                if (hasScore)
                  Badge('${attempt.score!.toStringAsFixed(0)}%',
                      icon: Icons.grade, color: scheme.primary),
                if (attempt.submittedAt != null)
                  Badge('Submitted ${attempt.submittedAt}',
                      icon: Icons.access_time, color: scheme.outline),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onGradeEssays,
              icon: const Icon(Icons.edit_document),
              tooltip: 'Grade essays',
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}