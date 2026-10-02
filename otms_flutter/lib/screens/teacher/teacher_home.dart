import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../state/auth_provider.dart';
import '../../state/theme_provider.dart';
import '../shared/widgets.dart';
import 'teacher_class_detail.dart';

/// Teacher dashboard: the join code students use, plus the teacher's classes.
class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});
  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  late Future<List<ClassModel>> _classes;
  late Future<String?> _code;

  @override
  void initState() {
    super.initState();
    _classes = Api.instance.classes();
    _code = Api.instance.getCode();
  }

  void _reload() => setState(() => _classes = Api.instance.classes());

  Future<void> _regenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Regenerate code?'),
        content: const Text(
          'Your current code stops working. Students already enrolled stay enrolled, but anyone with the old code can no longer join.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final code = await Api.instance.regenerateCode();
      if (!mounted) return;
      setState(() => _code = Future.value(code));
      showOk(context, 'New code generated.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _createClass() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateClassSheet(),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(
              theme.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () => theme.toggle(),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') auth.logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(auth.user?.fullName ?? ''),
              ),
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'teacher-home-fab',
        onPressed: _createClass,
        icon: const Icon(Icons.add),
        label: const Text('New class'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _codeCard(),
            const SizedBox(height: 20),
            Text(
              'Your classes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _classList(),
          ],
        ),
      ),
    );
  }

  Widget _codeCard() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Your join code',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Share this with students so they can find and enroll in your classes.',
              style: TextStyle(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<String?>(
              future: _code,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 24,
                    child: Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final code = snap.data ?? '——————';
                return Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        code,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        showOk(context, 'Code copied.');
                      },
                      icon: Icon(Icons.copy, color: scheme.onPrimaryContainer),
                    ),
                    IconButton(
                      tooltip: 'Regenerate',
                      onPressed: _regenerate,
                      icon: Icon(
                        Icons.refresh,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _classList() {
    return FutureBuilder<List<ClassModel>>(
      future: _classes,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: LoadingView(),
          );
        }
        if (snap.hasError) {
          return ErrorRetry(error: snap.error!, onRetry: _reload);
        }
        final classes = snap.data ?? [];
        if (classes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyState(
              icon: Icons.class_outlined,
              title: 'No classes yet',
              subtitle:
                  'Create your first class to add lessons and assessments.',
            ),
          );
        }
        return Column(
          children: classes
              .map(
                (c) => _ClassCard(
                  cls: c,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TeacherClassDetail(cls: c),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ClassCard extends StatelessWidget {
  final ClassModel cls;
  final VoidCallback onTap;
  const _ClassCard({required this.cls, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = hexColor(cls.color);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.menu_book_rounded, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cls.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (cls.studentCount != null)
                      Text(
                        '${cls.studentCount} student(s)',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') _deleteClass(context, cls.id);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete class'),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteClass(BuildContext context, int classId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete class?'),
        content: const Text(
          'This will delete the class and all its content, lessons, assessments, and homework.',
        ),
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
      await Api.instance.deleteClass(classId);
      if (!context.mounted) return;
      showOk(context, 'Class deleted');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
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
    '#6366F1',
    '#14B8A6',
    '#F59E0B',
    '#EF4444',
    '#8B5CF6',
    '#10B981',
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
      await Api.instance.createClass(
        _name.text.trim(),
        _desc.text.trim(),
        _color,
      );
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
          const Text(
            'New class',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
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
                    color: hexColor(c),
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3,
                          )
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
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create class'),
            ),
          ),
        ],
      ),
    );
  }
}
