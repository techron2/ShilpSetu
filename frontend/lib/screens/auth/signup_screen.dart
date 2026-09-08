import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../main_screen.dart';
import '../../theme/app_theme.dart';

/// Signup screen with name, email, password fields + role picker.
/// Role picker uses large card buttons — easy for low-digital-literacy users.
class SignupScreen extends StatefulWidget {
  final VoidCallback? onSwitchToLogin;
  const SignupScreen({super.key, this.onSwitchToLogin});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _selectedRole = 'artisan'; // default
  bool   _obscurePass  = true;

  // Whether we're on step 1 (form) or step 2 (role picker)
  bool _showRolePicker = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _goToRolePicker() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _showRolePicker = true);
  }

  Future<void> _submit() async {
    final auth = context.read<AppAuthProvider>();
    final ok = await auth.signUp(
      name:     _nameCtrl.text,
      email:    _emailCtrl.text,
      password: _passwordCtrl.text,
      role:     _selectedRole,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Sign up failed'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (ok && mounted) {
      // Direct redirect to Home page (index 0) with all prior routes cleared
      context.read<NavigationProvider>().setIndex(0);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: BackButton(
          onPressed: () {
            if (_showRolePicker) {
              setState(() => _showRolePicker = false);
            } else if (widget.onSwitchToLogin != null) {
              widget.onSwitchToLogin!();
            } else {
              Navigator.maybePop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _showRolePicker
              ? _buildRolePicker(auth)
              : _buildForm(auth),
        ),
      ),
    );
  }

  // ── Step 1: Details form ─────────────────────────────────────────────────
  Widget _buildForm(AppAuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tell us about yourself',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Step 1 of 2 — Enter your details',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.darkIndigo.withValues(alpha: 0.55)),
        ),
        const SizedBox(height: 28),

        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderGrey),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Name
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDec(
                    label: 'Full Name',
                    hint:  'Radha Devi',
                    icon:  Icons.person_outline_rounded,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDec(
                    label: 'Email Address',
                    hint:  'your@email.com',
                    icon:  Icons.email_outlined,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePass,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _goToRolePicker(),
                  decoration: _inputDec(
                    label: 'Password (min 6 characters)',
                    hint:  '••••••••',
                    icon:  Icons.lock_outline_rounded,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter a password';
                    if (v.length < 6) return 'Password must be 6+ characters';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                ElevatedButton.icon(
                  onPressed: _goToRolePicker,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Next: Choose Your Role'),
                ),
                const SizedBox(height: 20),

                // ── Go to Login ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Already have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium),
                    GestureDetector(
                      onTap: () {
                        if (widget.onSwitchToLogin != null) {
                          widget.onSwitchToLogin!();
                        } else {
                          Navigator.maybePop(context);
                        }
                      },
                      child: Text(
                        'Log In',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.primaryTerracotta,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Role picker ──────────────────────────────────────────────────
  Widget _buildRolePicker(AppAuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('What describes you?',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Step 2 of 2 — Choose your role',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.darkIndigo.withValues(alpha: 0.55)),
        ),
        const SizedBox(height: 32),

        _RoleCard(
          title:       'I am an Artisan',
          subtitle:    'I make and sell handcrafted products',
          icon:        Icons.handyman_rounded,
          value:       'artisan',
          groupValue:  _selectedRole,
          onTap:       () => setState(() => _selectedRole = 'artisan'),
        ),
        const SizedBox(height: 16),

        _RoleCard(
          title:       'I am a Buyer',
          subtitle:    'I want to discover and purchase crafts',
          icon:        Icons.shopping_bag_outlined,
          value:       'buyer',
          groupValue:  _selectedRole,
          onTap:       () => setState(() => _selectedRole = 'buyer'),
        ),
        const SizedBox(height: 36),

        ElevatedButton(
          onPressed: auth.isLoading ? null : _submit,
          child: auth.isLoading
              ? const SizedBox(
                  height: 22,
                  width:  22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : const Text('Create My Account'),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'You can always change your role later in Profile settings.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.darkIndigo.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDec({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText:  hint,
      prefixIcon: Icon(icon, color: AppTheme.primaryTerracotta),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryTerracotta, width: 2),
      ),
      filled:    true,
      fillColor: AppTheme.bgParchment,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

// ── Role card widget ────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onTap,
  });

  final String   title;
  final String   subtitle;
  final IconData icon;
  final String   value;
  final String   groupValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryTerracotta.withValues(alpha: 0.09)
              : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryTerracotta : AppTheme.borderGrey,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryTerracotta
                    : AppTheme.bgParchment,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  size: 28,
                  color: isSelected
                      ? Colors.white
                      : AppTheme.primaryTerracotta),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isSelected
                                ? AppTheme.primaryTerracotta
                                : AppTheme.darkIndigo,
                          )),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppTheme.primaryTerracotta
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryTerracotta
                      : AppTheme.borderGrey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
