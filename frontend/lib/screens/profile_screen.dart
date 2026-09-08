import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final user = auth.userModel;
    final isSignedIn = auth.isSignedIn;

    final displayName = user?.name ??
        auth.firebaseUser?.displayName ??
        'श्रीमती राधा देवी (Radha Devi)';
    final roleText = user != null
        ? (user.role == 'artisan'
            ? '⭐ शिल्पकार (Artisan)'
            : '🛒 खरीदार (Buyer)')
        : '⭐ मास्टर टेराकोटा शिल्पकार (Master Artisan)';
    final subText = user?.email ?? 'कला: गोरखपुर टेराकोटा क्लस्टर, उत्तर प्रदेश';

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Artisan Identity Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderGrey),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.primaryTerracotta,
                        child: Icon(Icons.person, color: Colors.white, size: 50),
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
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkIndigo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryOchre.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      roleText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.secondaryOchre,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subText,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Profile Options
            _buildProfileOption(
              icon: Icons.translate_rounded,
              iconColor: AppTheme.primaryTerracotta,
              title: "ऐप की भाषा (Language)",
              subtitle: "हिंदी (Hindi) चुनी गई है",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("भाषा चयन: हिंदी / English / Regional")),
                );
              },
            ),

            _buildProfileOption(
              icon: Icons.account_balance_rounded,
              iconColor: AppTheme.successGreen,
              title: "बैंक खाता और भुगतान (Bank Account)",
              subtitle: "भारतीय स्टेट बैंक (SBI) •••• 4021 जुड़ा हुआ है",
              onTap: () {},
            ),

            _buildProfileOption(
              icon: Icons.record_voice_over_rounded,
              iconColor: AppTheme.secondaryOchre,
              title: "शिल्पकार की कहानी (Artisan Story)",
              subtitle: "अपनी कला की 1 मिनट की ऑडियो कहानी रिकॉर्ड करें",
              onTap: () {},
            ),

            _buildProfileOption(
              icon: Icons.support_agent_rounded,
              iconColor: AppTheme.inTransitBlue,
              title: "शिल्पकार हेल्पलाइन (Toll-Free Support)",
              subtitle: "कॉल करें: 1800-120-SHILP (मुफ्त सहायता)",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("📞 हेल्पलाइन से संपर्क हो रहा है...")),
                );
              },
            ),

            const SizedBox(height: 16),

            // Sign out or Login button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isSignedIn ? AppTheme.warningRed : AppTheme.primaryTerracotta,
                  side: BorderSide(
                    color: isSignedIn ? AppTheme.warningRed : AppTheme.primaryTerracotta,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(isSignedIn ? Icons.logout_rounded : Icons.login_rounded),
                label: Text(
                  isSignedIn ? "लॉग आउट (Log Out)" : "लॉग इन / खाता बदलें (Login / Switch)",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () async {
                  if (isSignedIn) {
                    await auth.signOut();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("सफलतापूर्वक लॉग आउट हो गए (Logged out)")),
                      );
                    }
                  } else {
                    Navigator.of(context).pushAndRemoveUntil(
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
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            fontWeight: FontWeight.w700,
            color: AppTheme.darkIndigo,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF9CA3AF)),
        onTap: onTap,
      ),
    );
  }
}
