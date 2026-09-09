import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AppAuthProvider>();

    final ok = await auth.sendPasswordResetEmail(_emailCtrl.text.trim());
    if (mounted) {
      if (ok) {
        setState(() => _emailSent = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Failed to send reset link'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final auth = context.watch<AppAuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        leading: AppBackButton(color: AppTheme.darkIndigo),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          lang.getText('reset_title'),
          style: const TextStyle(color: AppTheme.darkIndigo, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTerracotta.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    size: 64,
                    color: AppTheme.primaryTerracotta,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                lang.getText('reset_title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.darkIndigo,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                lang.getText('reset_sub'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
              const SizedBox(height: 32),

              if (_emailSent) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.mark_email_read_rounded, size: 48, color: Color(0xFF059669)),
                      const SizedBox(height: 12),
                      Text(
                        lang.getText('reset_sent_msg'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Check your inbox and follow the instructions to set a new password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTerracotta,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: lang.getText('email'),
                      prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryTerracotta),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter your email';
                      if (!v.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTerracotta,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: auth.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          lang.getText('send_reset_link'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
