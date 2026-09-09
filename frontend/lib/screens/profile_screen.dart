import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/navigation_provider.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'artisan/profile_completion_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showLanguagePicker(BuildContext context, LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.translate_rounded, color: AppTheme.primaryTerracotta, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    lang.getText('choose_language'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkIndigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                lang.getText('choose_language_sub'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 18),
              ...LanguageProvider.supportedLanguages.map((opt) {
                final isSelected = opt.code == lang.currentLanguageCode;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      lang.setLanguage(opt.code);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryTerracotta.withValues(alpha: 0.08)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryTerracotta : const Color(0xFFE5E7EB),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(opt.flag, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opt.nameNative,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: AppTheme.darkIndigo,
                                  ),
                                ),
                                Text(
                                  opt.nameEnglish,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primaryTerracotta,
                              size: 22,
                            )
                          else
                            Icon(
                              Icons.radio_button_unchecked_rounded,
                              color: Colors.grey.shade400,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final user = auth.userModel;
    final isSignedIn = auth.isSignedIn;

    final displayName = user?.name.isNotEmpty == true
        ? user!.name
        : (auth.firebaseUser?.displayName?.isNotEmpty == true
            ? auth.firebaseUser!.displayName!
            : 'Radha Devi');

    final roleText = user != null
        ? (user.role == 'artisan'
            ? lang.getText('role_artisan_label')
            : lang.getText('role_buyer_label'))
        : lang.getText('role_artisan_label');

    final subText = user?.email.isNotEmpty == true
        ? user!.email
        : 'Gorakhpur Terracotta Cluster';

    final currentLangOption = LanguageProvider.supportedLanguages.firstWhere(
      (l) => l.code == lang.currentLanguageCode,
      orElse: () => LanguageProvider.supportedLanguages.first,
    );

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ── Artisan Identity Card with gradient header ───────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderGrey),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Gradient / Cover header band
                  Container(
                    width: double.infinity,
                    height: 90,
                    decoration: BoxDecoration(
                      image: (user?.coverPhotoUrl.isNotEmpty == true)
                          ? DecorationImage(
                              image: NetworkImage(user!.coverPhotoUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      gradient: (user?.coverPhotoUrl.isNotEmpty == true)
                          ? null
                          : const LinearGradient(
                              colors: [AppTheme.primaryTerracotta, Color(0xFFC25A47)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                  ),
                  // Avatar — overlaps the gradient
                  Transform.translate(
                    offset: const Offset(0, -40),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: AppTheme.primaryTerracotta,
                                backgroundImage: (user?.profilePhotoUrl.isNotEmpty == true)
                                    ? NetworkImage(user!.profilePhotoUrl)
                                    : null,
                                child: (user?.profilePhotoUrl.isNotEmpty == true)
                                    ? null
                                    : const Icon(Icons.person, color: Colors.white, size: 52),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppTheme.successGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkIndigo,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryOchre.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            roleText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.secondaryOchre,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            subText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Artisan Story Section (Expandable) ─────────────────────────
            if (user?.role == 'artisan' || user == null) ...[
              const SizedBox(height: 16),
              _ArtisanStorySection(
                story: user?.artisanStory ?? '',
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileCompletionScreen(initialStep: 3)),
                  );
                },
              ),
            ],

            const SizedBox(height: 16),

            // ── Profile Options ────────────────────────────────────────────
            _buildProfileOption(
              icon: Icons.badge_rounded,
              iconColor: AppTheme.primaryTerracotta,
              title: lang.getText('profile_completion_title'),
              subtitle: lang.getText('profile_completion_sub'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF9CA3AF)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileCompletionScreen()),
                );
              },
            ),

            _buildProfileOption(
              icon: Icons.translate_rounded,
              iconColor: AppTheme.primaryTerracotta,
              title: lang.getText('app_language_heading'),
              subtitle: '${currentLangOption.flag}  ${currentLangOption.nameNative} (${currentLangOption.nameEnglish})',
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF9CA3AF)),
              onTap: () => _showLanguagePicker(context, lang),
            ),

            _buildProfileOption(
              icon: Icons.account_balance_rounded,
              iconColor: AppTheme.successGreen,
              title: lang.getText('bank_account_title'),
              subtitle: lang.getText('bank_account_sub'),
              onTap: () {},
            ),

            _buildProfileOption(
              icon: Icons.record_voice_over_rounded,
              iconColor: AppTheme.secondaryOchre,
              title: lang.getText('artisan_story_title'),
              subtitle: lang.getText('artisan_story_sub'),
              onTap: () {},
            ),

            _buildProfileOption(
              icon: Icons.support_agent_rounded,
              iconColor: AppTheme.inTransitBlue,
              title: lang.getText('helpline_title'),
              subtitle: lang.getText('helpline_sub'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('📞 ${lang.getText('helpline_sub')}')),
                );
              },
            ),

            const SizedBox(height: 16),

            // ── Sign out button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isSignedIn ? AppTheme.warningRed : AppTheme.primaryTerracotta,
                  side: BorderSide(
                    color: isSignedIn ? AppTheme.warningRed : AppTheme.primaryTerracotta,
                    width: 1.8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(isSignedIn ? Icons.logout_rounded : Icons.login_rounded),
                label: Text(
                  isSignedIn ? lang.getText('sign_out_btn') : lang.getText('login_switch_btn'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () async {
                  if (isSignedIn) {
                    await auth.signOut();
                    if (context.mounted) {
                      context.read<NavigationProvider>().setIndex(0);
                      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthGate()),
                        (route) => false,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(lang.getText('logged_out_msg'))),
                      );
                    }
                  } else {
                    context.read<NavigationProvider>().setIndex(0);
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthGate()),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderGrey),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkIndigo,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3.0),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF9CA3AF)),
      ),
    );
  }
}

class _ArtisanStorySection extends StatefulWidget {
  final String story;
  final VoidCallback onEdit;

  const _ArtisanStorySection({
    required this.story,
    required this.onEdit,
  });

  @override
  State<_ArtisanStorySection> createState() => _ArtisanStorySectionState();
}

class _ArtisanStorySectionState extends State<_ArtisanStorySection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final hasStory = widget.story.trim().isNotEmpty;
    final isLong = widget.story.trim().length > 120;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryTerracotta.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTerracotta.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTerracotta.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: AppTheme.primaryTerracotta,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.getText('artisan_story_title'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkIndigo,
                        ),
                      ),
                      Text(
                        lang.getText('step_story'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: lang.getText('profile_completion_title'),
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    color: AppTheme.primaryTerracotta,
                    size: 24,
                  ),
                  onPressed: widget.onEdit,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderGrey),

          // Story Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: !hasStory
                ? InkWell(
                    onTap: widget.onEdit,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.secondaryOchre.withValues(alpha: 0.3),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_circle_outline_rounded,
                            color: AppTheme.secondaryOchre,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              lang.getText('story_field_hint'),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF4B5563),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 250),
                        crossFadeState: _isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: Text(
                          widget.story,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: Color(0xFF374151),
                          ),
                        ),
                        secondChild: Text(
                          widget.story,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                      if (isLong) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isExpanded
                                    ? lang.getText('show_less')
                                    : lang.getText('read_more'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryTerracotta,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: AppTheme.primaryTerracotta,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

