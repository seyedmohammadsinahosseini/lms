import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../state/auth_provider.dart';
import '../../state/theme_provider.dart';
import '../shared/widgets.dart';
import 'class_detail.dart';
import 'join_teacher_screen.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});
  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  late Future<List<ClassModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.instance.classes();
  }

  void _reload() {
    setState(() => _future = Api.instance.classes());
  }

  Future<void> _openJoin() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const JoinTeacherScreen()));
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My classes'),
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
                value: 'profile',
                enabled: false,
                child: Text(auth.user?.fullName ?? ''),
              ),
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'student-home-fab',
        onPressed: _openJoin,
        icon: const Icon(Icons.qr_code_2),
        label: const Text('Join with code'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<ClassModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (snap.hasError) {
              return ErrorRetry(error: snap.error!, onRetry: _reload);
            }
            final classes = snap.data ?? [];
            if (classes.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.school_outlined,
                    title: 'No classes yet',
                    subtitle:
                        'Enter your teacher\'s code to see their classes and enroll.',
                    action: FilledButton.icon(
                      onPressed: _openJoin,
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Join with code'),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: classes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _ClassCard(
                cls: classes[i],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ClassDetail(cls: classes[i]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
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
                    if (cls.teacherName != null)
                      Text(
                        cls.teacherName!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    if (cls.description != null &&
                        cls.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        cls.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
