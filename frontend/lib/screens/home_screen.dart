import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_theme.dart';
import 'artisan/my_products_screen.dart';
import 'artisan/business_assistant_screen.dart';
import 'analytics/analytics_screen.dart';
import 'cluster/virtual_cluster_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Card with Cultural Aesthetic
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryTerracotta, Color(0xFFD05C49)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryTerracotta.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person_pin, color: Colors.white, size: 34),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Consumer<AppAuthProvider>(
                        builder: (context, auth, _) {
                          final name = auth.userModel?.name ?? auth.firebaseUser?.displayName ?? 'Artisan';
                          final cluster = auth.userModel?.artisanCluster;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'नमस्ते, $name 🙏',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cluster != null && cluster.isNotEmpty
                                    ? cluster
                                    : 'ShilpSetu Artisan',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Audio Assistant Pill (Essential for Low Literacy Artisans)
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BusinessAssistantScreen()),
                  ),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.support_agent_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "व्यापार सहायक से पूछें (AI Assistant)",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Dashboard Quick Metrics
          const Text(
            "आज का विवरण (Today's Summary)",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkIndigo,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  context,
                  icon: Icons.inventory_2_rounded,
                  iconColor: AppTheme.primaryTerracotta,
                  number: "14",
                  label: "शिल्प उत्पाद\n(Catalog Items)",
                  onTap: () => context.read<NavigationProvider>().setIndex(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  context,
                  icon: Icons.local_shipping_rounded,
                  iconColor: AppTheme.secondaryOchre,
                  number: "2",
                  label: "नए ऑर्डर\n(Orders to Pack)",
                  onTap: () => context.read<NavigationProvider>().setIndex(2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _buildEarningsCard(context),

          const SizedBox(height: 24),

          // Large Accessible Action Buttons
          const Text(
            "त्वरित कार्य (Quick Actions)",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkIndigo,
            ),
          ),
          const SizedBox(height: 12),

          // Prominent AI Business Assistant Card
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BusinessAssistantScreen()),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.darkIndigo, Color(0xFF2C3258)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.darkIndigo.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTerracotta.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryTerracotta.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '💬 AI व्यापार सहायक (Business Guide)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'कीमत, बिक्री और त्योहारों के ऑफर पर सीधी सलाह लें',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            icon: const Icon(Icons.inventory_2_rounded, size: 24),
            label: const Text('🏺 मेरे उत्पाद देखें (My Products)'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyProductsScreen()),
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            icon: const Icon(Icons.bar_chart_rounded, size: 24),
            label: const Text('📊 बिज़नेस एनालिटिक्स व चार्ट (Analytics)'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkIndigo,
              foregroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            icon: const Icon(Icons.hub_rounded, size: 24),
            label: const Text('🤝 वर्चुअल शिल्प क्लस्टर (Virtual Cluster Hub)'),
            onPressed: () => VirtualClusterDialog.show(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8C6E14),
              side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            icon: const Icon(Icons.add_a_photo_rounded, size: 24),
            label: const Text('📸 नया शिल्प जोड़ें (Add New Craft)'),
            onPressed: () => context.read<NavigationProvider>().setIndex(1),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            icon: const Icon(Icons.receipt_long_rounded, size: 24),
            label: const Text('📦 ऑर्डर और डिलीवरी देखें (View Orders)'),
            onPressed: () => context.read<NavigationProvider>().setIndex(2),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String number,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderGrey),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              number,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkIndigo,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsCard(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC8E6C9)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppTheme.successGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.currency_rupee, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "इस महीने की कुल कमाई (This Month's Earnings) →",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "₹ 12,450",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.successGreen, size: 18),
          ],
        ),
      ),
    );
  }
}
