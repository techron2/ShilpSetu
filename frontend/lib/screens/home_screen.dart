import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/product_provider.dart';
import '../services/buyer_service.dart';
import '../theme/app_theme.dart';
import 'analytics/analytics_screen.dart';
import 'artisan/add_product_screen.dart';
import 'artisan/business_assistant_screen.dart';
import 'artisan/product_detail_screen.dart';
import 'cluster/virtual_cluster_dialog.dart';

/// Redesigned Artisan Home screen matching heritage/terracotta theme.
/// Connected 100% to real Firestore analytics, products, orders, and user profile.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _analytics;
  int? _productCount;
  int _ordersToPack = 0;
  List<Map<String, dynamic>> _recentOrders = [];
  String? _fetchedUserName;
  bool _isLoading = true;
  String? _lastLoadedArtisanId;
  int _currentBannerIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AppAuthProvider>(context);
    final artisanId = auth.currentArtisanId;
    if (artisanId != _lastLoadedArtisanId) {
      _lastLoadedArtisanId = artisanId;
      _loadData(artisanId);
    }
  }

  Future<void> _loadData([String? targetId]) async {
    if (!mounted) return;
    final auth = context.read<AppAuthProvider>();
    final artisanId = targetId ?? auth.currentArtisanId;

    setState(() => _isLoading = true);

    // Fetch analytics, products, orders, and user profile concurrently
    final results = await Future.wait([
      BuyerService.instance.getAnalyticsSummary(artisanId),
      http.get(
        Uri.parse('${ApiConfig.products}?artisan_id=$artisanId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3), onTimeout: () => http.Response('{}', 500)).catchError((_) => http.Response('{}', 500)),
      http.get(
        Uri.parse('${ApiConfig.orders}?artisan_id=$artisanId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3), onTimeout: () => http.Response('{}', 500)).catchError((_) => http.Response('{}', 500)),
      http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/users/$artisanId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3), onTimeout: () => http.Response('{}', 500)).catchError((_) => http.Response('{}', 500)),
    ]);

    // Keep ProductProvider synchronized
    if (mounted) {
      context.read<ProductProvider>().fetchProducts(artisanId: artisanId);
    }

    final summary = results[0] as Map<String, dynamic>?;
    final prodResp = results[1] as http.Response;
    final ordResp = results[2] as http.Response;
    final userResp = results[3] as http.Response;

    // Parse product count
    int? count;
    if (prodResp.statusCode == 200) {
      try {
        final decoded = jsonDecode(prodResp.body) as Map<String, dynamic>;
        final list = decoded['products'] as List<dynamic>?;
        count = list?.length;
      } catch (_) {}
    }

    // Parse orders and calculate orders to pack (pending/ready to pack)
    List<Map<String, dynamic>> recentOrders = [];
    int toPack = 0;
    if (ordResp.statusCode == 200) {
      try {
        final decoded = jsonDecode(ordResp.body) as Map<String, dynamic>;
        final list = (decoded['orders'] as List<dynamic>?) ?? [];
        for (var o in list) {
          final s = (o['status'] ?? '').toString().toLowerCase();
          if (s == 'pending' || s == 'confirmed' || s == 'ready_to_pack' || s == 'placed') {
            toPack++;
          }
        }
        final sorted = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        sorted.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
        recentOrders = sorted.take(2).toList();
      } catch (_) {}
    }

    // Parse user name
    String? userName;
    if (userResp.statusCode == 200) {
      try {
        final decoded = jsonDecode(userResp.body) as Map<String, dynamic>;
        userName = decoded['user']?['name']?.toString();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _analytics = summary;
        if (count != null) _productCount = count;
        _ordersToPack = toPack;
        _recentOrders = recentOrders;
        if (userName != null && userName.isNotEmpty) _fetchedUserName = userName;
        _isLoading = false;
      });
    }
  }

  // ── Derived analytics values ───────────────────────────────────────────────

  Map<String, dynamic>? get _data {
    if (_analytics == null) return null;
    if (_analytics!.containsKey('data') && _analytics!['data'] is Map) {
      return Map<String, dynamic>.from(_analytics!['data'] as Map);
    }
    return _analytics;
  }

  double get _revenueThisMonth =>
      (_data?['revenue_this_month'] as num?)?.toDouble() ?? 0.0;

  double get _totalRevenue =>
      (_data?['total_revenue'] as num?)?.toDouble() ?? 0.0;

  double? get _revenueGrowthPct =>
      (_data?['revenue_growth_pct'] as num?)?.toDouble();

  Map<String, dynamic>? get _bestSellingProduct =>
      _data?['best_selling_product'] as Map<String, dynamic>?;

  String _getArtisanFirstName(AppAuthProvider auth) {
    String fullName = _fetchedUserName ??
        auth.userModel?.name ??
        auth.firebaseUser?.displayName ??
        'Artisan';
    fullName = fullName.trim();
    if (fullName.isEmpty) return 'Artisan';
    final first = fullName.split(' ').first;
    return first[0].toUpperCase() + first.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final auth = context.watch<AppAuthProvider>();
    final firstName = _getArtisanFirstName(auth);

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadData(),
          color: AppTheme.primaryTerracotta,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Top Header ─────────────────────────────────────────────
                _buildHeader(context, language, auth),

                const SizedBox(height: 12),

                // ── 2. Greeting Section ───────────────────────────────────────
                _buildGreetingSection(firstName, language),

                const SizedBox(height: 16),

                // ── 3. Promotional Banner / Carousel ──────────────────────────
                _buildPromoCarousel(context, language),

                const SizedBox(height: 20),

                // ── 4. Three Stat Cards ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildStatCardsRow(context, language),
                ),

                const SizedBox(height: 24),

                // ── 5. Quick Actions (2x2 Grid) ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildQuickActionsSection(context, language),
                ),

                const SizedBox(height: 24),

                // ── 6. AI Business Guide Card ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildAiBusinessGuideCard(context, language),
                ),

                const SizedBox(height: 24),

                // ── 7. Recent Orders ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildRecentOrdersSection(context, language),
                ),

                const SizedBox(height: 24),

                // ── 8. Top Products ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildTopProductsSection(context, language),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. Header Widget ─────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, LanguageProvider language, AppAuthProvider auth) {
    final hasUnread = _ordersToPack > 0;
    final initial = _getArtisanFirstName(auth).substring(0, 1).toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 4),
      child: Row(
        children: [
          // App Logo / Emblem
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryTerracotta, Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryTerracotta.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.palette_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // App Title & Tagline
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  language.getText('app_title'),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.darkIndigo,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  language.getText('app_tagline'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8C6E14),
                  ),
                ),
              ],
            ),
          ),
          // Notification Bell with unread badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppTheme.darkIndigo, size: 26),
                tooltip: 'Notifications',
                onPressed: () => context.read<NavigationProvider>().setIndex(2),
              ),
              if (hasUnread)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          // Profile Avatar -> navigates to Profile
          InkWell(
            onTap: () => context.read<NavigationProvider>().setIndex(3),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.secondaryOchre, width: 2),
              ),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppTheme.primaryTerracotta.withValues(alpha: 0.15),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryTerracotta,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Greeting Section ──────────────────────────────────────────────────────

  Widget _buildGreetingSection(String firstName, LanguageProvider language) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${language.getText('home_greeting_prefix')}, $firstName',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkIndigo,
                ),
              ),
              const SizedBox(width: 6),
              const Text('🙏', style: TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            language.getText('home_overview_subtitle'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Promotional Banner / Carousel ─────────────────────────────────────────

  Widget _buildPromoCarousel(BuildContext context, LanguageProvider language) {
    final slides = [
      {
        'title': language.getText('banner_sell_title'),
        'desc': language.getText('banner_sell_desc'),
        'cta': language.getText('banner_sell_cta'),
        'icon': Icons.storefront_rounded,
        'gradient': const [Color(0xFFC04B36), Color(0xFFDF6B4F)],
        'action': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddProductScreen()),
        ),
      },
      {
        'title': language.getText('banner_cluster_title'),
        'desc': language.getText('banner_cluster_desc'),
        'cta': language.getText('banner_cluster_cta'),
        'icon': Icons.hub_rounded,
        'gradient': const [Color(0xFF283655), Color(0xFF4A6572)],
        'action': () => VirtualClusterDialog.show(context),
      },
      {
        'title': language.getText('banner_passport_title'),
        'desc': language.getText('banner_passport_desc'),
        'cta': language.getText('banner_passport_cta'),
        'icon': Icons.verified_outlined,
        'gradient': const [Color(0xFF1E5244), Color(0xFF2C7A63)],
        'action': () => context.read<NavigationProvider>().setIndex(1),
      },
    ];

    return Column(
      children: [
        SizedBox(
          height: 148,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentBannerIndex = i),
            itemCount: slides.length,
            itemBuilder: (context, index) {
              final s = slides[index];
              final gradient = s['gradient'] as List<Color>;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              s['title'] as String,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s['desc'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: s['action'] as VoidCallback,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  s['cta'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: gradient[0],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          s['icon'] as IconData,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            slides.length,
            (idx) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentBannerIndex == idx ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentBannerIndex == idx
                    ? AppTheme.primaryTerracotta
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 4. Three Stat Cards in a Row ─────────────────────────────────────────────

  Widget _buildStatCardsRow(BuildContext context, LanguageProvider language) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        final prodCount = _productCount ?? productProvider.products.length;
        final revenue = _revenueThisMonth > 0 ? _revenueThisMonth : _totalRevenue;
        final growth = _revenueGrowthPct;

        return Row(
          children: [
            // Stat 1: Products Listed
            Expanded(
              child: _buildSingleStatCard(
                context,
                title: language.getText('stat_products_listed'),
                value: _isLoading ? '...' : prodCount.toString(),
                trend: language.getText('stat_active'),
                trendColor: AppTheme.primaryTerracotta,
                icon: Icons.inventory_2_outlined,
                iconColor: AppTheme.primaryTerracotta,
                onTap: () => context.read<NavigationProvider>().setIndex(1),
              ),
            ),
            const SizedBox(width: 10),
            // Stat 2: Orders to Pack
            Expanded(
              child: _buildSingleStatCard(
                context,
                title: language.getText('stat_orders_to_pack'),
                value: _isLoading ? '...' : _ordersToPack.toString(),
                trend: language.getText('stat_pending'),
                trendColor: const Color(0xFFD97706),
                icon: Icons.outbox_rounded,
                iconColor: const Color(0xFFD97706),
                onTap: () => context.read<NavigationProvider>().setIndex(2),
              ),
            ),
            const SizedBox(width: 10),
            // Stat 3: This Month's Earnings
            Expanded(
              child: _buildSingleStatCard(
                context,
                title: language.getText('stat_earnings_month'),
                value: _isLoading ? '...' : '₹${revenue.toStringAsFixed(0)}',
                trend: growth != null && growth > 0
                    ? '↑ ${growth.toStringAsFixed(0)}%'
                    : (growth != null && growth < 0 ? '↓ ${growth.abs().toStringAsFixed(0)}%' : ''),
                trendColor: AppTheme.successGreen,
                icon: Icons.currency_rupee_rounded,
                iconColor: AppTheme.successGreen,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSingleStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String trend,
    required Color trendColor,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEFE7DC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                if (trend.isNotEmpty)
                  Text(
                    trend,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: trendColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkIndigo,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Quick Actions (2x2 Grid) ──────────────────────────────────────────────

  Widget _buildQuickActionsSection(BuildContext context, LanguageProvider language) {
    final actions = [
      {
        'title': language.getText('qa_add_craft_title'),
        'sub': language.getText('qa_add_craft_sub'),
        'icon': Icons.add_photo_alternate_rounded,
        'color': AppTheme.primaryTerracotta,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddProductScreen()),
        ),
      },
      {
        'title': language.getText('qa_orders_title'),
        'sub': language.getText('qa_orders_sub'),
        'icon': Icons.local_shipping_outlined,
        'color': const Color(0xFFD97706),
        'onTap': () => context.read<NavigationProvider>().setIndex(2),
      },
      {
        'title': language.getText('qa_analytics_title'),
        'sub': language.getText('qa_analytics_sub'),
        'icon': Icons.insights_rounded,
        'color': const Color(0xFF2B3A67),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
        ),
      },
      {
        'title': language.getText('qa_cluster_title'),
        'sub': language.getText('qa_cluster_sub'),
        'icon': Icons.groups_outlined,
        'color': const Color(0xFF0D9488),
        'onTap': () => VirtualClusterDialog.show(context),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: language.getText('quick_actions_title'),
          seeAllText: language.getText('see_all'),
          onSeeAll: () => context.read<NavigationProvider>().setIndex(1),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.38,
          ),
          itemBuilder: (context, index) {
            final a = actions[index];
            final color = a['color'] as Color;
            return InkWell(
              onTap: a['onTap'] as VoidCallback,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEFE7DC)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(a['icon'] as IconData, color: color, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      a['title'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkIndigo,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a['sub'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── 6. AI Business Guide Card ────────────────────────────────────────────────

  Widget _buildAiBusinessGuideCard(BuildContext context, LanguageProvider language) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2036), Color(0xFF2B3356)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B2036).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryOchre.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.secondaryOchre.withValues(alpha: 0.5)),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppTheme.secondaryOchre,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  language.getText('ai_guide_title'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            language.getText('ai_guide_desc'),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessAssistantScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTerracotta,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                elevation: 3,
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: Text(
                language.getText('ai_guide_btn'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 7. Recent Orders Section ─────────────────────────────────────────────────

  Widget _buildRecentOrdersSection(BuildContext context, LanguageProvider language) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: language.getText('recent_orders_title'),
          seeAllText: language.getText('see_all'),
          onSeeAll: () => context.read<NavigationProvider>().setIndex(2),
        ),
        const SizedBox(height: 12),
        if (_recentOrders.isEmpty && !_isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEFE7DC)),
            ),
            child: Center(
              child: Text(
                language.getText('no_recent_orders'),
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentOrders.length,
            itemBuilder: (context, index) {
              final o = _recentOrders[index];
              final buyer = o['buyer_name']?.toString() ?? 'Buyer';
              final title = o['product_title']?.toString() ?? 'Craft Order';
              final price = (o['total_price'] as num?)?.toDouble() ?? 0.0;
              final status = o['status']?.toString() ?? 'delivered';
              final timeStr = _formatOrderDate(o['created_at']?.toString(), language);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  onTap: () => context.read<NavigationProvider>().setIndex(2),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.secondaryOchre.withValues(alpha: 0.15),
                          child: const Icon(Icons.person_rounded, color: AppTheme.secondaryOchre, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    buyer,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.darkIndigo,
                                    ),
                                  ),
                                  Text(
                                    timeStr,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatusBadge(status, language),
                                  Text(
                                    '₹${price.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.primaryTerracotta,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ── 8. Top Products Section ──────────────────────────────────────────────────

  Widget _buildTopProductsSection(BuildContext context, LanguageProvider language) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        final products = productProvider.products;
        final best = _bestSellingProduct;

        // Find best-selling Product object for image and full details
        Product? topProd1;
        if (best != null && products.isNotEmpty) {
          final id = best['id']?.toString();
          topProd1 = products.firstWhere(
            (p) => p.id == id || p.title == best['title'],
            orElse: () => products.first,
          );
        } else if (products.isNotEmpty) {
          topProd1 = products.first;
        }

        Product? topProd2;
        if (products.length > 1) {
          topProd2 = products.firstWhere(
            (p) => p.id != topProd1?.id,
            orElse: () => products[1],
          );
        }

        final topList = [topProd1, topProd2].whereType<Product>().toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: language.getText('top_products_title'),
              seeAllText: language.getText('see_all'),
              onSeeAll: () => context.read<NavigationProvider>().setIndex(1),
            ),
            const SizedBox(height: 12),
            if (topList.isEmpty && !_isLoading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEFE7DC)),
                ),
                child: Center(
                  child: Text(
                    language.getText('no_top_products'),
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  ),
                ),
              )
            else
              ...List.generate(topList.length, (idx) {
                final prod = topList[idx];
                final rank = idx + 1;
                final isNo1 = rank == 1;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(
                          productId: prod.id,
                          initialProduct: prod,
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // Rank badge
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isNo1
                                  ? AppTheme.secondaryOchre
                                  : const Color(0xFF9CA3AF),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '#$rank',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Thumbnail image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: prod.imageUrl.isNotEmpty
                                  ? Image.network(
                                      prod.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _buildFallbackThumbnail(),
                                    )
                                  : _buildFallbackThumbnail(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Product details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.darkIndigo,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '₹${prod.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryTerracotta,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Sales or Best seller badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isNo1
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isNo1
                                  ? (best != null && best['units_sold'] != null
                                      ? '${best['units_sold']} ${language.getText('sales_count')}'
                                      : language.getText('best_seller_badge'))
                                  : '${prod.stockQuantity} ${language.getText('stock_available')}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isNo1
                                    ? const Color(0xFFB45309)
                                    : AppTheme.successGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // ── Helper Widgets ───────────────────────────────────────────────────────────

  Widget _buildSectionHeader({
    required String title,
    required String seeAllText,
    required VoidCallback onSeeAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkIndigo,
          ),
        ),
        InkWell(
          onTap: onSeeAll,
          child: Text(
            seeAllText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryTerracotta,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackThumbnail() {
    return Container(
      color: AppTheme.secondaryOchre.withValues(alpha: 0.12),
      child: const Icon(Icons.palette_rounded, color: AppTheme.secondaryOchre, size: 24),
    );
  }

  Widget _buildStatusBadge(String status, LanguageProvider language) {
    final s = status.toLowerCase();
    Color bg;
    Color text;
    String label;

    if (s == 'delivered') {
      bg = const Color(0xFFE8F5E9);
      text = AppTheme.successGreen;
      label = language.getText('status_delivered');
    } else if (s == 'shipped') {
      bg = const Color(0xFFE0F2FE);
      text = const Color(0xFF0284C7);
      label = language.getText('status_shipped');
    } else if (s == 'ready_to_pack') {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFD97706);
      label = language.getText('status_ready_to_pack');
    } else {
      bg = const Color(0xFFFFFBEB);
      text = AppTheme.secondaryOchre;
      label = language.getText('status_pending');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }

  String _formatOrderDate(String? isoString, LanguageProvider language) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diffDays = DateTime(now.year, now.month, now.day)
          .difference(DateTime(dt.year, dt.month, dt.day))
          .inDays;

      if (diffDays == 0) {
        return language.getText('time_today');
      } else if (diffDays == 1) {
        return language.getText('time_yesterday');
      } else {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${dt.day} ${months[dt.month - 1]}';
      }
    } catch (_) {
      return isoString.split('T').first;
    }
  }
}
