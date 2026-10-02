import 'package:flutter/material.dart' hide Badge;

import '../../models/models.dart';
import '../../services/api.dart';
import '../shared/widgets.dart';

/// Student enters a teacher's code, sees every class that teacher offers,
/// and enrolls in the ones they want. Switching teachers is just entering a
/// different code, so a student can study different subjects with different
/// teachers. Returns `true` when at least one enrollment happened.
class JoinTeacherScreen extends StatefulWidget {
  const JoinTeacherScreen({super.key});
  @override
  State<JoinTeacherScreen> createState() => _JoinTeacherScreenState();
}

class _JoinTeacherScreenState extends State<JoinTeacherScreen> {
  final _code = TextEditingController();
  bool _looking = false;
  bool _enrolledSomething = false;
  CodeLookup? _result;
  final _enrolling = <int>{};

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() => _looking = true);
    try {
      final res = await Api.instance.lookupCode(code);
      setState(() => _result = res);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<void> _enroll(LookupClass cls) async {
    setState(() => _enrolling.add(cls.id));
    try {
      await Api.instance.enroll(cls.id);
      _enrolledSomething = true;
      // Refresh the lookup so the enrolled flag updates.
      final res = await Api.instance.lookupCode(_code.text.trim());
      if (mounted) setState(() => _result = res);
      if (mounted) showOk(context, 'Enrolled in ${cls.name}');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _enrolling.remove(cls.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_enrolledSomething);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Join a teacher')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Enter your teacher\'s code',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'They can share it from their dashboard.',
              style: TextStyle(color: scheme.outline),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Teacher code',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                      hintText: 'e.g. ABC123',
                    ),
                    onSubmitted: (_) => _lookup(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _looking ? null : _lookup,
                    child: _looking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Look up'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_result != null) _teacherResult(_result!),
          ],
        ),
      ),
    );
  }

  Widget _teacherResult(CodeLookup r) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primary,
              child: Text(
                r.teacherName.isNotEmpty ? r.teacherName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.teacherName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${r.classes.length} class(es) available',
                  style: TextStyle(color: scheme.outline),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (r.classes.isEmpty)
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No classes offered yet',
          )
        else
          ...r.classes.map((c) => _classTile(c)),
      ],
    );
  }

  Widget _classTile(LookupClass c) {
    final color = hexColor(c.color);
    final busy = _enrolling.contains(c.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.menu_book_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (c.description != null && c.description!.isNotEmpty)
                    Text(
                      c.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (c.enrolled)
              const Badge('Enrolled', icon: Icons.check, color: Colors.green)
            else if (busy)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              FilledButton.tonal(
                onPressed: () => _enroll(c),
                child: const Text('Enroll'),
              ),
          ],
        ),
      ),
    );
  }
}
