import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_provider.dart';
import '../shared/widgets.dart';

/// Multi-step sign-up: each screen collects one group of fields
/// (1) name + role, (2) email, (3) password. A progress bar shows position.
class RegisterFlow extends StatefulWidget {
  const RegisterFlow({super.key});
  @override
  State<RegisterFlow> createState() => _RegisterFlowState();
}

class _RegisterFlowState extends State<RegisterFlow> {
  final _pageController = PageController();
  int _step = 0;
  bool _submitting = false;

  // Collected values.
  final _name = TextEditingController();
  String _role = 'student';
  final _email = TextEditingController();
  final _teacherInvite = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // Per-step form keys so we validate only the visible fields.
  final _step0Key = GlobalKey<FormState>();
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  static const _titles = ['About you', 'Your email', 'Set a password'];

  @override
  void dispose() {
    _pageController.dispose();
    _name.dispose();
    _email.dispose();
    _teacherInvite.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _next() {
    final keys = [_step0Key, _step1Key, _step2Key];
    if (!keys[_step].currentState!.validate()) return;
    if (_step < 2) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step--);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await context.read<AuthProvider>().register(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        role: _role,
        teacherInvite:
            _role == 'teacher' && _teacherInvite.text.trim().isNotEmpty
            ? _teacherInvite.text.trim()
            : null,
      );
      if (mounted) Navigator.of(context).pop(); // AuthGate shows the home.
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _back),
        title: Text(_titles[_step]),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: _ProgressBar(step: _step, total: 3),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [_stepAbout(), _stepEmail(), _stepPassword()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _next,
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_step < 2 ? 'Continue' : 'Create account'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pad(Widget child) =>
      SingleChildScrollView(padding: const EdgeInsets.all(24), child: child);

  Widget _stepAbout() => _pad(
    Form(
      key: _step0Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tell us who you are',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
          ),
          const SizedBox(height: 24),
          Text('I am a', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          _RoleCard(
            selected: _role == 'student',
            icon: Icons.backpack_outlined,
            title: 'Student',
            subtitle: 'Join classes with a teacher code',
            onTap: () => setState(() => _role = 'student'),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            selected: _role == 'teacher',
            icon: Icons.co_present_outlined,
            title: 'Teacher',
            subtitle: 'Create classes, lessons and assessments',
            onTap: () => setState(() => _role = 'teacher'),
          ),
        ],
      ),
    ),
  );

  Widget _stepEmail() => _pad(
    Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What is your email?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'You will use it to sign in.',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'Enter your email';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
        ],
      ),
    ),
  );

  Widget _stepPassword() => _pad(
    Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create a password',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'At least 10 characters.',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 20),
          if (_role == 'teacher') ...[
            TextFormField(
              controller: _teacherInvite,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Teacher invitation',
                helperText:
                    'Required when public teacher sign-up is restricted',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) => (v == null || v.length < 10)
                ? 'Use at least 10 characters'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) =>
                v != _password.text ? 'Passwords do not match' : null,
          ),
        ],
      ),
    ),
  );
}

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressBar({required this.step, required this.total});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: i < total - 1 ? 8 : 0),
            decoration: BoxDecoration(
              color: i <= step
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _RoleCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.10)
              : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? scheme.primary : scheme.outline),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: scheme.outline, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
