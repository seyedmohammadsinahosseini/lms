import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../../services/api.dart';
import '../../shared/widgets.dart';
import '../../student/content_viewer.dart';
import '../content_editor.dart';

/// Teacher lessons manager: create lessons, expand to see/add content
/// (video links, notes, long-form booklets).
class TLessonsTab extends StatefulWidget {
  final int classId;
  const TLessonsTab({super.key, required this.classId});
  @override
  State<TLessonsTab> createState() => _TLessonsTabState();
}

class _TLessonsTabState extends State<TLessonsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Lesson>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = Api.instance.lessons(widget.classId);
  }

  @override
  void didUpdateWidget(covariant TLessonsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _future = Api.instance.lessons(widget.classId);
    }
  }

  void _reload() =>
      setState(() => _future = Api.instance.lessons(widget.classId));

  Future<void> _createLesson() async {
    final title = await _promptText(context, 'New lesson', 'Lesson title');
    if (title == null || title.trim().isEmpty) return;
    try {
      await Api.instance.createLesson(widget.classId, title.trim());
      if (!mounted) return;
      showOk(context, 'Lesson created');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: FutureBuilder<List<Lesson>>(
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
              subtitle: 'Add your first lesson, then fill it with content.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: lessons.length,
            itemBuilder: (_, i) => _TLessonCard(
              key: ValueKey(lessons[i].id),
              lesson: lessons[i],
              onDeleted: _reload,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'teacher-lessons-fab',
        onPressed: _createLesson,
        icon: const Icon(Icons.add),
        label: const Text('Lesson'),
      ),
    );
  }
}

class _TLessonCard extends StatefulWidget {
  final Lesson lesson;
  final VoidCallback onDeleted;
  const _TLessonCard({
    super.key,
    required this.lesson,
    required this.onDeleted,
  });
  @override
  State<_TLessonCard> createState() => _TLessonCardState();
}

class _TLessonCardState extends State<_TLessonCard> {
  Future<List<Content>>? _contents;

  @override
  void didUpdateWidget(covariant _TLessonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lesson.id != widget.lesson.id) _contents = null;
  }

  void _load() {
    setState(() => _contents = Api.instance.contents(widget.lesson.id));
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

  Future<void> _addContent() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ContentEditor(lessonId: widget.lesson.id),
      ),
    );
    if (added == true) _load();
  }

  Future<void> _deleteContent(int contentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete content?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Api.instance.deleteContent(contentId);
      if (!mounted) return;
      showOk(context, 'Content deleted');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _deleteLesson() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete lesson?'),
        content: const Text('This will delete the lesson and all its content.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Api.instance.deleteLesson(widget.lesson.id);
      if (!mounted) return;
      showOk(context, 'Lesson deleted');
      widget.onDeleted();
    } catch (e) {
      if (mounted) showError(context, e);
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
            if (open && _contents == null) _load();
          },
          leading: CircleAvatar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              '${widget.lesson.position + 1}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          title: Text(
            widget.lesson.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _deleteLesson();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete lesson'),
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            if (_contents != null)
              FutureBuilder<List<Content>>(
                future: _contents,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: ErrorRetry(error: snap.error!, onRetry: _load),
                    );
                  }
                  final items = snap.data ?? [];
                  return Column(
                    children: [
                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No content yet.'),
                        )
                      else
                        ...items.map(
                          (c) => ListTile(
                            leading: Icon(_iconFor(c.type)),
                            title: Text(c.title),
                            subtitle: Text(
                              c.type.toUpperCase(),
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') _deleteContent(c.id);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ContentViewer(content: c),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addContent,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add content'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small reusable single-field prompt dialog.
Future<String?> _promptText(BuildContext context, String title, String label) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, ctrl.text),
          child: const Text('Add'),
        ),
      ],
    ),
  );
}
