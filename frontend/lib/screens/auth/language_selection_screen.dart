import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import 'signup_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final VoidCallback? onSwitchToLogin;
  const LanguageSelectionScreen({super.key, this.onSwitchToLogin});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late String _selectedCode;

  @override
  void initState() {
    super.initState();
    _selectedCode = context.read<LanguageProvider>().currentLanguageCode;
  }

  void _proceedToSignup() {
    context.read<LanguageProvider>().setLanguage(_selectedCode);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignupScreen(onSwitchToLogin: widget.onSwitchToLogin),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        leading: AppBackButton(color: AppTheme.darkIndigo),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Language / भाषा',
          style: TextStyle(color: AppTheme.darkIndigo, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTerracotta.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.translate_rounded,
                    size: 48,
                    color: AppTheme.primaryTerracotta,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lang.getText('choose_language'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.darkIndigo,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                lang.getText('choose_language_sub'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Language options list
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: LanguageProvider.supportedLanguages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final option = LanguageProvider.supportedLanguages[idx];
                  final isSelected = option.code == _selectedCode;

                  return InkWell(
                    onTap: () {
                      setState(() => _selectedCode = option.code);
                      context.read<LanguageProvider>().setLanguage(option.code);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white70,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryTerracotta : Colors.black12,
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryTerracotta.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Text(option.flag, style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.nameNative,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: AppTheme.darkIndigo,
                                  ),
                                ),
                                Text(
                                  option.nameEnglish,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primaryTerracotta,
                              size: 26,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _proceedToSignup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTerracotta,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lang.getText('continue'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
