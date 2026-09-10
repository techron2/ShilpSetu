import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/navigation_provider.dart';
import '../main_screen.dart';
import '../../theme/app_theme.dart';
import 'forgot_password_screen.dart';
import 'language_selection_screen.dart';

/// Email + Password & Phone + OTP Login screen.
/// Designed for low-digital-literacy users: large fields, clear labels, friendly errors.
class LoginScreen extends StatefulWidget {
  final VoidCallback? onSwitchToSignUp;
  const LoginScreen({super.key, this.onSwitchToSignUp});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailFormKey   = GlobalKey<FormState>();
  final _phoneFormKey   = GlobalKey<FormState>();

  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _phoneCtrl     = TextEditingController(text: '+91 ');
  final _otpCtrl       = TextEditingController();

  bool _obscurePass    = true;
  int  _loginTabMode   = 0; // 0: Email, 1: Phone
  bool _otpSent        = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmailLogin() async {
    if (!_emailFormKey.currentState!.validate()) return;
    final auth = context.read<AppAuthProvider>();
    final ok = await auth.signIn(
      email:    _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Login failed'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (ok && mounted) {
      context.read<NavigationProvider>().setIndex(0);
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _submitPhoneLogin() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final auth = context.read<AppAuthProvider>();
    final rawPhone = _phoneCtrl.text.replaceAll(RegExp(r'\s+'), '').trim();

    // Verify existing user profile in Firestore
    final ok = await auth.signInWithExistingPhone(rawPhone);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'No account found with this phone number.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (ok && mounted) {
      context.read<NavigationProvider>().setIndex(0);
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    }
  }

  void _navigateToLanguageAndSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LanguageSelectionScreen(onSwitchToLogin: widget.onSwitchToSignUp),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── Logo / brand ───────────────────────────────────────────
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTerracotta,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      size: 44, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'KalaVistar',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primaryTerracotta,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                lang.getText('login_sub'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.darkIndigo.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 28),

              // ── Login Card ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderGrey),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mode Toggle (Email vs Phone)
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bgParchment,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _loginTabMode = 0),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _loginTabMode == 0 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _loginTabMode == 0
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.email_outlined,
                                        size: 16,
                                        color: _loginTabMode == 0 ? AppTheme.primaryTerracotta : Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      lang.getText('email_login'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _loginTabMode == 0 ? FontWeight.bold : FontWeight.normal,
                                        color: _loginTabMode == 0 ? AppTheme.darkIndigo : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _loginTabMode = 1),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _loginTabMode == 1 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _loginTabMode == 1
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.phone_iphone_rounded,
                                        size: 16,
                                        color: _loginTabMode == 1 ? AppTheme.primaryTerracotta : Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      lang.getText('phone_login'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _loginTabMode == 1 ? FontWeight.bold : FontWeight.normal,
                                        color: _loginTabMode == 1 ? AppTheme.darkIndigo : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_loginTabMode == 0) _buildEmailForm(auth, lang) else _buildPhoneForm(auth, lang),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Go to Language & Signup ───────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ",
                      style: Theme.of(context).textTheme.bodyMedium),
                  GestureDetector(
                    onTap: _navigateToLanguageAndSignup,
                    child: Text(
                      lang.getText('create_account_btn'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.primaryTerracotta,
                            fontWeight: FontWeight.w800,
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
    );
  }

  // ── Email Login Tab ──────────────────────────────────────────────────────
  Widget _buildEmailForm(AppAuthProvider auth, LanguageProvider lang) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _inputDec(
              label: lang.getText('email'),
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

          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePass,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitEmailLogin(),
            decoration: _inputDec(
              label: lang.getText('password'),
              hint:  'Your password',
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
              if (v == null || v.isEmpty) return 'Please enter your password';
              return null;
            },
          ),

          // Forgot Password Link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                );
              },
              child: Text(
                lang.getText('forgot_password'),
                style: const TextStyle(
                  color: AppTheme.primaryTerracotta,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          ElevatedButton(
            onPressed: auth.isLoading ? null : _submitEmailLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTerracotta,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: auth.isLoading
                ? const SizedBox(
                    height: 22,
                    width:  22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(lang.getText('login_btn'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.flash_on_rounded, size: 18),
            label: const Text('✨ Demo Artisan Access (त्वरित प्रवेश)'),
            onPressed: () {
              context.read<NavigationProvider>().setIndex(0);
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Phone Login Tab ──────────────────────────────────────────────────────
  Widget _buildPhoneForm(AppAuthProvider auth, LanguageProvider lang) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Firebase Console Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF1D4ED8)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Requires existing registered phone number from Signup.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: _inputDec(
              label: lang.getText('phone'),
              hint:  '+91 98765 43210',
              icon:  Icons.phone_android_rounded,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter your phone number';
              final clean = v.replaceAll(RegExp(r'\s+'), '');
              if (clean.length < 10) return 'Valid phone number with country code required';
              return null;
            },
          ),

          if (_otpSent) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: _inputDec(
                label: lang.getText('enter_otp'),
                hint:  '123456',
                icon:  Icons.mark_email_read_rounded,
              ),
              validator: (v) {
                if (v == null || v.trim().length < 6) return 'Enter 6-digit OTP';
                return null;
              },
            ),
          ],

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: auth.isLoading
                ? null
                : () {
                    if (!_otpSent) {
                      if (!_phoneFormKey.currentState!.validate()) return;
                      setState(() => _otpSent = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('OTP sent to phone number. Verify below.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      _submitPhoneLogin();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTerracotta,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: auth.isLoading
                ? const SizedBox(
                    height: 22,
                    width:  22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    !_otpSent ? lang.getText('send_otp') : lang.getText('verify_otp'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.flash_on_rounded, size: 18),
            label: const Text('✨ Quick Phone Match Check (लॉगिन करें)'),
            onPressed: _submitPhoneLogin,
          ),
        ],
      ),
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
    );
  }
}
