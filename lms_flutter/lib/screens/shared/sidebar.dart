import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_provider.dart';
import 'widgets.dart';

/// Responsive application shell: compact phones use an overlay menu, tablets
/// use a NavigationRail-sized panel, and wide screens use the full sidebar.
class Sidebar extends StatefulWidget {
  final Widget child;
  final bool isTeacher;
  final int? selectedClassId;
  final Function(int)? onClassSelected;
  final VoidCallback? onDashboardPressed;
  final VoidCallback? onClassesPressed;
  final VoidCallback? onCreateClassPressed;

  const Sidebar({
    super.key,
    required this.child,
    required this.isTeacher,
    this.selectedClassId,
    this.onClassSelected,
    this.onDashboardPressed,
    this.onClassesPressed,
    this.onCreateClassPressed,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _collapsed = false;

  Future<void> _showCompactMenu() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        child: _navigation(expanded: true, closeAfterTap: sheetContext),
      ),
    ),
  );

  Future<void> _showProfile() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _ProfileDialog(),
    );
  }

  VoidCallback? _closeThen(BuildContext? sheet, VoidCallback? callback) {
    if (callback == null) return null;
    return () {
      if (sheet != null) Navigator.pop(sheet);
      callback();
    };
  }

  Widget _navigation({required bool expanded, BuildContext? closeAfterTap}) {
    final selectedClass = widget.selectedClassId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NavItem(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Dashboard',
          expanded: expanded,
          selected: !selectedClass,
          onTap: _closeThen(closeAfterTap, widget.onDashboardPressed),
        ),
        _NavItem(
          icon: Icons.class_outlined,
          selectedIcon: Icons.class_,
          label: 'My classes',
          expanded: expanded,
          selected: selectedClass,
          onTap: _closeThen(closeAfterTap, widget.onClassesPressed),
        ),
        if (widget.isTeacher)
          _NavItem(
            icon: Icons.add_circle_outline,
            selectedIcon: Icons.add_circle,
            label: 'Create class',
            expanded: expanded,
            selected: false,
            onTap: _closeThen(closeAfterTap, widget.onCreateClassPressed),
          ),
      ],
    );
  }

  Widget _userButton({required bool expanded}) {
    final user = context.watch<AuthProvider>().user;
    final name = user?.fullName ?? 'User';
    return Tooltip(
      message: expanded ? '' : 'Account',
      child: InkWell(
        onTap: _showProfile,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
              ),
              if (expanded) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        widget.isTeacher ? 'Teacher' : 'Student',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _demoBanner() {
    final auth = context.watch<AuthProvider>();
    if (!auth.isDemo) return const SizedBox.shrink();
    final expires = auth.demoExpiresAt;
    return Material(
      color: Colors.amber.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.science_outlined, size: 18, color: Colors.black87),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                expires == null
                    ? 'Demo sandbox · temporary data'
                    : 'Demo sandbox · expires $expires',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentWithBanner() => Column(
    children: [
      _demoBanner(),
      Expanded(child: widget.child),
    ],
  );

  Widget _desktopShell(double width) {
    final expanded = width >= 1024 && !_collapsed;
    final panelWidth = expanded ? 260.0 : 76.0;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: panelWidth,
          child: Material(
            color: scheme.surface,
            shape: Border(right: BorderSide(color: scheme.outlineVariant)),
            child: SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    height: 68,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.school_outlined, color: scheme.primary),
                        if (expanded) ...[
                          const SizedBox(width: 8),
                          const Text(
                            'LMS',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _navigation(expanded: expanded),
                    ),
                  ),
                  if (width >= 1024)
                    IconButton(
                      tooltip: expanded
                          ? 'Collapse navigation'
                          : 'Expand navigation',
                      onPressed: () => setState(() => _collapsed = !_collapsed),
                      icon: Icon(
                        expanded ? Icons.chevron_left : Icons.chevron_right,
                      ),
                    ),
                  const Divider(height: 1),
                  _userButton(expanded: expanded),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _contentWithBanner()),
      ],
    );
  }

  Widget _phoneShell() {
    final scheme = Theme.of(context).colorScheme;
    final user = context.watch<AuthProvider>().user;
    return Column(
      children: [
        Material(
          color: scheme.surface,
          elevation: 1,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 58,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Navigation',
                    onPressed: _showCompactMenu,
                    icon: const Icon(Icons.menu),
                  ),
                  Icon(Icons.school_outlined, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'LMS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Account',
                    onPressed: _showProfile,
                    icon: CircleAvatar(
                      radius: 16,
                      child: Text(
                        (user?.fullName.isNotEmpty ?? false)
                            ? user!.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _contentWithBanner()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 600
        ? _phoneShell()
        : _desktopShell(constraints.maxWidth),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool expanded;
  final bool selected;
  final VoidCallback? onTap;
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Tooltip(
        message: expanded ? '' : label,
        child: ListTile(
          minTileHeight: 48,
          selected: selected,
          selectedTileColor: scheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(selected ? selectedIcon : icon),
          title: expanded ? Text(label) : null,
          onTap: onTap,
          contentPadding: expanded
              ? const EdgeInsets.symmetric(horizontal: 12)
              : const EdgeInsets.symmetric(horizontal: 17),
        ),
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog();

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _name;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: context.read<AuthProvider>().user?.fullName ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_name.text.trim().length < 2) {
      showError(context, 'Enter your full name.');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().updateProfile(_name.text.trim());
      if (mounted) showOk(context, 'Profile updated.');
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPassword.text.length < 10) {
      showError(context, 'The new password must have at least 10 characters.');
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      showError(context, 'The new passwords do not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().changePassword(
        _currentPassword.text,
        _newPassword.text,
      );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      if (mounted) {
        showOk(context, 'Password changed; other sessions were revoked.');
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text(
                        (user?.fullName.isNotEmpty ?? false)
                            ? user!.fullName[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? '',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(user?.email ?? ''),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _name,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _saveProfile,
                  child: const Text('Save profile'),
                ),
                const Divider(height: 40),
                if (context.watch<AuthProvider>().isDemo)
                  const Text(
                    'Password changes are unavailable in temporary demo sandboxes.',
                  )
                else ...[
                  Text(
                    'Change password',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _currentPassword,
                    enabled: !_busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newPassword,
                    enabled: !_busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _confirmPassword,
                    enabled: !_busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _busy ? null : _changePassword,
                    child: const Text('Change password'),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _busy
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await context.read<AuthProvider>().logout();
                        },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int hexColor(String hex) {
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  return int.parse(value, radix: 16);
}
