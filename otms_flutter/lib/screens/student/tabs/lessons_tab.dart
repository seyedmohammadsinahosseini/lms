import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../../services/api_client.dart';
import '../../shared/widgets.dart';
import '../content_viewer.dart';

/// Lists lessons for a class; expanding one shows its contents.
class LessonsTab extends StatefulWidget {
  final int classId;
  const LessonsTab({super.key, required this.classId});
  @override
  State<LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<LessonsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Lesson>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.lessons(widget.classId);
  }

  void _reload() =>
      setState(() => _future = ApiClient.instance.lessons(widget.classId));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Lesson>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return ErrorRetry(error: snap.error!, onRetry: _reload);
        }
        final lessons = snap.data ?? [];
        if (lessons.isEmpty) {
          return const EmptyState(
            icon: Icons.auto_stories_outlined,
            title: 'No lessons yet',
            subtitle: 'Your teacher hasn\'t added any lessons.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: lessons.length,
          itemBuilder: (_, i) => _LessonCard(lesson: lessons[i]),
        );
      },
    );
  }
}

class _LessonCard extends StatefulWidget {
  final Lesson lesson;
  const _LessonCard({required this.lesson});
  @override
  State<_LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<_LessonCard> {
  Future<List<Content>>? _contents;

  void _loadOnce() {
    _contents ??= ApiClient.instance.contents(widget.lesson.id);
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'video':
        return Icons.play_circle_outline;
      case 'booklet':
        return Icons.book_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          onExpansionChanged: (open) {
            if (open) setState(_loadOnce);
          },
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            child: Text('${widget.lesson.position + 1}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600)),
          ),
          title: Text(widget.lesson.title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            FutureBuilder<List<Content>>(
              future: _contents,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No content in this lesson yet.'),
                  );
                }
                return Column(
                  children: items
                      .map((c) => ListTile(
                            leading: Icon(_iconFor(c.type)),
                            title: Text(c.title),
                            subtitle: Text(c.type.toUpperCase(),
                                style: const TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ContentViewer(content: c),
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
