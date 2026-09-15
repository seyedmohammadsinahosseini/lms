import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_provider.dart';

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

class _SidebarState extends State<Sidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;
  bool _isCollapsed = false;
  bool _isUserMenuOpen = false;
  OverlayEntry? _userMenuOverlay;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _widthAnimation = Tween<double>(
      begin: 260,
      end: 72,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _removeUserMenuOverlay();
    super.dispose();
  }

  void _toggleCollapse() {
    setState(() {
      _isCollapsed = !_isCollapsed;
      if (_isCollapsed) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _toggleUserMenu() {
    if (_isUserMenuOpen) {
      _removeUserMenuOverlay();
    } else {
      _showUserMenuOverlay();
    }
  }

  void _showUserMenuOverlay() {
    final overlay = Overlay.of(context);
    final size = MediaQuery.of(context).size;

    _userMenuOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeUserMenuOverlay,
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
          // User menu panel - CENTERED
          Positioned(
            left: (size.width - 500) / 2,
            top: (size.height - 580) / 2,
            width: 500,
            height: 580,
            child: Material(
              elevation: 24,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: _buildUserMenuContent(),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_userMenuOverlay!);
    setState(() => _isUserMenuOpen = true);
  }

  void _removeUserMenuOverlay() {
    _userMenuOverlay?.remove();
    _userMenuOverlay = null;
    if (mounted) setState(() => _isUserMenuOpen = false);
  }

Widget _buildUserMenuContent() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final fullName = user?.fullName ?? 'Unknown';
    final email = user?.email ?? '';

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.isTeacher ? 'Teacher' : 'Student',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),

              ],
            ),
              ),
              IconButton(
                onPressed: _removeUserMenuOverlay,
                icon: const Icon(Icons.close, size: 24),
                tooltip: 'Close',
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Info Section
                Text(
                  'Profile Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoCard(Icons.email_outlined, 'Email', email.isEmpty ? 'Not set' : email),
                _buildInfoCard(Icons.location_on_outlined, 'Location', 'Not set'),
                _buildInfoCard(Icons.school_outlined, 'Role', widget.isTeacher ? 'Teacher' : 'Student'),
                _buildInfoCard(Icons.badge_outlined, 'Bio', 'No bio added yet'),
                const SizedBox(height: 24),

                // Divider
                const Divider(thickness: 1.5),
                const SizedBox(height: 16),

                // Actions Section
                Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _removeUserMenuOverlay();
                      _showEditProfileDialog();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 22),
                    label: const Text('Edit Profile', style: TextStyle(fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _removeUserMenuOverlay();
                      _showChangePasswordDialog();
                    },
                    icon: const Icon(Icons.lock_outline, size: 22),
                    label: const Text('Change Password', style: TextStyle(fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Sign out
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      _removeUserMenuOverlay();
                      context.read<AuthProvider>().logout();
                    },
                    icon: const Icon(Icons.logout, size: 22),
                    label: const Text('Sign Out', style: TextStyle(fontSize: 16)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final nameController = TextEditingController(text: user?.fullName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final bioController = TextEditingController();
    final locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated (demo)')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (newController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password changed (demo)')),
              );
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, _) {
        final width = _widthAnimation.value;
        return Row(
          children: [
            // Sidebar
            Container(
              width: width,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Logo / App name
                  SizedBox(
                    height: 72,
                    child: Center(
                      child: _isCollapsed
                          ? Icon(
                              Icons.school_outlined,
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.school_outlined,
                                  size: 28,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'OTMS',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const Divider(height: 1),

                  // Navigation items
                  Expanded(
                    child: _isCollapsed
                        ? _buildCollapsedNavContent()
                        : _buildExpandedNavContent(),
                  ),



                  // Collapse button at bottom
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _toggleCollapse,
                        icon: Icon(_isCollapsed ? Icons.chevron_right : Icons.chevron_left, size: 20),
label: _isCollapsed
    ? const SizedBox.shrink()
    : const Text('Collapse', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),

                  // User info section at bottom
                  _buildUserSection(),
                ],
              ),
            ),

            // Main content area
            Expanded(
              child: widget.child,
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required VoidCallback? onTap,
    required bool isSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedNavItem({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    required bool isSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                icon,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedNavContent() {
    return ListView(
      key: const ValueKey('expanded'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // SECTION 1: Dashboard (separated)
        _buildNavItem(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Dashboard',
          onTap: widget.onDashboardPressed,
          isSelected: widget.selectedClassId == null,
        ),
        // Separator line after Dashboard
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Divider(thickness: 1.5),
        ),

        // SECTION 2: Classes / Navigation
        _buildNavItem(
          icon: Icons.class_outlined,
          selectedIcon: Icons.class_,
          label: 'My Classes',
          onTap: widget.onClassesPressed,
          isSelected: widget.selectedClassId != null,
        ),
        if (widget.isTeacher) ...[
          _buildNavItem(
            icon: Icons.add_circle_outline,
            selectedIcon: Icons.add_circle,
            label: 'Create Class',
            onTap: widget.onCreateClassPressed,
            isSelected: false,
          ),
        ],
      ],
    );
  }

  Widget _buildCollapsedNavContent() {
    return ListView(
      key: const ValueKey('collapsed'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Dashboard
        _buildCollapsedNavItem(
          icon: Icons.dashboard_outlined,
          tooltip: 'Dashboard',
          onTap: widget.onDashboardPressed,
          isSelected: widget.selectedClassId == null,
        ),
        // Small separator in collapsed mode
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Divider(thickness: 1),
        ),

        // My Classes
        _buildCollapsedNavItem(
          icon: Icons.class_outlined,
          tooltip: 'My Classes',
          onTap: widget.onClassesPressed,
          isSelected: widget.selectedClassId != null,
        ),
        if (widget.isTeacher) ...[
          _buildCollapsedNavItem(
            icon: Icons.add_circle_outline,
            tooltip: 'Create Class',
            onTap: widget.onCreateClassPressed,
            isSelected: false,
          ),
        ],
      ],
    );
  }

  Widget _buildUserSection() {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final fullName = user?.fullName ?? 'User';
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: InkWell(
        onTap: _toggleUserMenu,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedOpacity(
          opacity: _isCollapsed ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isCollapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.isTeacher ? 'Teacher' : 'Student',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: colorScheme.outline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

int hexColor(String hex) {
  hex = hex.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return int.parse(hex, radix: 16);
}