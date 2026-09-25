import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/buyer_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/inr.dart';
import '../../widgets/app_back_button.dart';

/// Analytics dashboard screen for artisans.
/// Displays key sales metrics, order fulfillment rates, and a 6-month sales
/// trend chart powered by `fl_chart`.
class AnalyticsScreen extends StatefulWidget {
  final String? artisanId;
  const AnalyticsScreen({super.key, this.artisanId});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _analytics;
  Map<String, dynamic>? _trustScore;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final aid = widget.artisanId ?? auth.effectiveArtisanId;

    if (aid == null) {
      if (!mounted) return;
      setState(() {
        _analytics = null;
        _trustScore = null;
        _isLoading = false;
      });
      return;
    }

    final results = await Future.wait([
      BuyerService.instance.getAnalyticsSummary(aid),
      BuyerService.instance.getTrustScore(aid),
    ]);

    if (!mounted) return;
    setState(() {
      _analytics = results[0];
      _trustScore = results[1];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('📊 Artisan Business Analytics'),
        backgroundColor: AppTheme.primaryTerracotta,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Refresh metrics',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryTerracotta,
              ),
            )
          : _analytics == null
          ? _buildUnavailableState()
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.primaryTerracotta,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDataSourceNotice(),
                    const SizedBox(height: 12),
                    _buildHeaderBanner(),
                    const SizedBox(height: 16),
                    _buildKpiGrid(),
                    const SizedBox(height: 20),
                    _buildChartCard(),
                    const SizedBox(height: 20),
                    _buildTrustReliabilityCard(),
                    const SizedBox(height: 20),
                    _buildStatusBreakdownCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  String get _dataSource => _analytics?['_source']?.toString() ?? 'unknown';
  bool get _usesLiveSales => _dataSource == 'firestore';
  bool get _hasTrustHistory {
    final explicit = _trustScore?['has_history'];
    if (explicit is bool) return explicit;
    return ((_trustScore?['total_orders'] as num?)?.toInt() ?? 0) > 0;
  }

  Widget _buildUnavailableState() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primaryTerracotta,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.query_stats_rounded,
            size: 68,
            color: AppTheme.primaryTerracotta.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 18),
          const Text(
            'Analytics are unavailable',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkIndigo,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check the KalaVistar backend connection, then try again. No sample totals are shown as live data.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry analytics'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSourceNotice() {
    late final IconData icon;
    late final Color color;
    late final String title;
    late final String detail;

    switch (_dataSource) {
      case 'firestore':
        icon = Icons.cloud_done_rounded;
        color = AppTheme.successGreen;
        title = 'Live sales data';
        detail = 'Calculated from recorded KalaVistar orders';
        break;
      case 'baseline':
        icon = Icons.science_outlined;
        color = AppTheme.secondaryOchre;
        title = 'Demo sales snapshot';
        detail = 'Sample history for storytelling — not live orders';
        break;
      case 'mock':
        icon = Icons.science_outlined;
        color = AppTheme.secondaryOchre;
        title = 'Demo sales snapshot';
        detail = 'Backend demo data — not live orders';
        break;
      case 'error_fallback':
        icon = Icons.cloud_off_rounded;
        color = AppTheme.warningRed;
        title = 'Demo fallback data';
        detail = 'Live analytics could not be reached';
        break;
      default:
        icon = Icons.info_outline_rounded;
        color = const Color(0xFF667085);
        title = 'Analytics source unknown';
        detail = 'Refresh before using these figures';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header Banner ───────────────────────────────────────────────────────────
  Widget _buildHeaderBanner() {
    final growth =
        (_analytics?['revenue_growth_pct'] as num?)?.toDouble() ?? 0.0;
    final isPositive = growth >= 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryTerracotta, Color(0xFF9E3D1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTerracotta.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _usesLiveSales
                      ? 'Sales & Growth Performance'
                      : 'Sample Sales & Growth Story',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatInr(
                    ((_analytics?['total_revenue'] as num?)?.toDouble() ?? 0.0),
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${isPositive ? '+' : ''}$growth% this month',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  // ── 4 KPI Grid Cards ────────────────────────────────────────────────────────
  Widget _buildKpiGrid() {
    final totalOrders = _analytics?['total_orders'] ?? 0;
    final aov = (_analytics?['average_order_value'] as num?)?.toDouble() ?? 0.0;
    final bestSeller =
        _analytics?['best_selling_product'] as Map<String, dynamic>?;
    final bestTitle = bestSeller?['title'] ?? 'Handcrafted Artifacts';
    final bestUnits = bestSeller?['units_sold'] ?? 0;
    final trustScore = _hasTrustHistory
        ? (_trustScore?['trust_score'] as num?)?.toDouble()
        : null;
    final trustBadge = _hasTrustHistory
        ? (_trustScore?['badge']?.toString())
        : null;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: [
        _kpiCard(
          icon: Icons.shopping_bag_outlined,
          color: const Color(0xFF2E7D32),
          label: 'Total Orders',
          value: '$totalOrders orders',
          subtext: '${_analytics?['completed_orders'] ?? 0} delivered',
        ),
        _kpiCard(
          icon: Icons.receipt_long_outlined,
          color: const Color(0xFF1565C0),
          label: 'Avg Order Value',
          value: formatInr(aov),
          subtext: 'per transaction',
        ),
        _kpiCard(
          icon: Icons.star_outline_rounded,
          color: const Color(0xFFD4AF37),
          label: 'Best Seller',
          value: bestTitle.length > 15
              ? '${bestTitle.substring(0, 14)}…'
              : bestTitle,
          subtext: '$bestUnits units sold',
        ),
        _kpiCard(
          icon: Icons.verified_outlined,
          color: AppTheme.primaryTerracotta,
          label: 'Trust Score',
          value: trustScore == null
              ? '—'
              : '${trustScore.toStringAsFixed(1)} / 5.0',
          subtext: trustBadge == null || trustBadge.isEmpty
              ? 'No trust history yet'
              : trustBadge,
        ),
      ],
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE5DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2C221E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sales Trend Chart Card (fl_chart) ───────────────────────────────────────
  Widget _buildChartCard() {
    final trends = (_analytics?['monthly_trend'] as List?) ?? [];
    if (trends.isEmpty) {
      return const SizedBox.shrink();
    }

    final double maxRevenue = trends.fold<double>(1000.0, (max, item) {
      final rev = (item['revenue'] as num?)?.toDouble() ?? 0.0;
      return rev > max ? rev : max;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE5DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Sales Trend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C221E),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Last 6 months revenue in INR (₹)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8D7B74)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTerracotta.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '6 Months',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryTerracotta,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxRevenue * 1.25,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF2C221E),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final monthName = trends[groupIndex]['month'] ?? '';
                      return BarTooltipItem(
                        '$monthName\n₹${rod.toY.toStringAsFixed(0)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                  touchCallback: (event, response) {
                    if (response != null && response.spot != null) {
                      setState(() {
                        _touchedIndex = response.spot!.touchedBarGroupIndex;
                      });
                    } else {
                      setState(() {
                        _touchedIndex = -1;
                      });
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        if (value >= 1000) {
                          return Text(
                            '${(value / 1000).toStringAsFixed(0)}k',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF8D7B74),
                            ),
                          );
                        }
                        return Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8D7B74),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < trends.length) {
                          final isSelected = idx == _touchedIndex;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              trends[idx]['month']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? AppTheme.primaryTerracotta
                                    : const Color(0xFF6B5E57),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxRevenue / 4,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: const Color(0xFFF0EBE6), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(trends.length, (i) {
                  final rev = (trends[i]['revenue'] as num?)?.toDouble() ?? 0.0;
                  final isTouched = i == _touchedIndex;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: rev,
                        gradient: LinearGradient(
                          colors: isTouched
                              ? [
                                  const Color(0xFFD4AF37),
                                  AppTheme.primaryTerracotta,
                                ]
                              : [
                                  AppTheme.primaryTerracotta,
                                  const Color(0xFFE07A5F),
                                ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Trust & Reliability Card ────────────────────────────────────────────────
  Widget _buildTrustReliabilityCard() {
    if (_trustScore == null || !_hasTrustHistory) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F6F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5DDD5)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFF8D7B74), size: 24),
            SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trust history not available yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C221E),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Completed orders and buyer ratings will build this score over time.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A6B63),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final compRate = (_trustScore?['completion_rate_pct'] as num?)?.toInt();
    final rating = (_trustScore?['rating'] as num?)?.toDouble();
    final trustScore = (_trustScore?['trust_score'] as num?)?.toDouble();
    final badge = _trustScore?['badge']?.toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6F0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5DDD5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_rounded,
                color: AppTheme.successGreen,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'Trust & Artisan Reliability',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C221E),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4AF37)),
                ),
                child: Text(
                  badge == null || badge.isEmpty ? 'Building history' : badge,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8C6E14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _trustMetricCol(
                  'Order Fulfillment',
                  compRate == null ? '—' : '$compRate%',
                  compRate == null ? null : compRate / 100,
                ),
              ),
              Container(width: 1, height: 40, color: const Color(0xFFD9D0C7)),
              Expanded(
                child: _trustMetricCol(
                  'Buyer Rating',
                  rating == null ? '—' : '★ ${rating.toStringAsFixed(1)}',
                  rating == null ? null : rating / 5.0,
                ),
              ),
              Container(width: 1, height: 40, color: const Color(0xFFD9D0C7)),
              Expanded(
                child: _trustMetricCol(
                  'Trust Score',
                  trustScore == null
                      ? '—'
                      : '${trustScore.toStringAsFixed(1)} / 5',
                  trustScore == null ? null : trustScore / 5.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trustMetricCol(String label, String value, double? progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2C221E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF7A6B63)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (progress ?? 0).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: const Color(0xFFE8E0D8),
              valueColor: const AlwaysStoppedAnimation(
                AppTheme.primaryTerracotta,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Order Status Breakdown ──────────────────────────────────────────────────
  Widget _buildStatusBreakdownCard() {
    final statusMap =
        (_analytics?['order_status_counts'] as Map<String, dynamic>?) ?? {};

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE5DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _usesLiveSales ? 'Live Order Pipeline' : 'Sample Order Pipeline',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C221E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statusChip(
                'Pending',
                statusMap['pending'] ?? 0,
                const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
              _statusChip(
                'Confirmed',
                statusMap['confirmed'] ?? 0,
                const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 8),
              _statusChip(
                'Shipped',
                statusMap['shipped'] ?? 0,
                const Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 8),
              _statusChip(
                'Delivered',
                statusMap['delivered'] ?? 0,
                const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
