import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'artisan/my_products_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'artisan/business_assistant_screen.dart';
import 'analytics/analytics_screen.dart';
import 'cluster/virtual_cluster_dialog.dart';
import 'buyer/buyer_home_screen.dart';
import 'buyer/buyer_orders_screen.dart';
import 'buyer/rfq_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final isBuyer = auth.userModel?.isBuyer ?? false;

    return isBuyer
        ? const _BuyerMainScreen()
        : const _ArtisanMainScreen();
  }
}

// ─── Artisan Shell ─────────────────────────────────────────────────────────────

class _ArtisanMainScreen extends StatefulWidget {
  const _ArtisanMainScreen();

  @override
  State<_ArtisanMainScreen> createState() => _ArtisanMainScreenState();
}

class _ArtisanMainScreenState extends State<_ArtisanMainScreen> {
  DateTime? _lastBackPressTime;

  // Catalog tab reuses the live My Products experience (embedded mode:
  // no inner AppBar, shell title applies) instead of hardcoded demo items.
  static const List<Widget> _screens = [
    HomeScreen(),
    MyProductsScreen(embedded: true),
    OrdersScreen(),
    ProfileScreen(),
  ];

  static const List<String> _titles = [
    "शिल्पसेतु • होम (Home)",
    "शिल्प सूची (Catalog)",
    "ऑर्डर्स व डिलीवरी (Orders)",
    "शिल्पकार प्रोफ़ाइल (Profile)",
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (nav.currentIndex != 0) {
          nav.setIndex(0);
        } else {
          final now = DateTime.now();
          if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
            _lastBackPressTime = now;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("ऐप से बाहर निकलने के लिए दोबारा बैक दबाएं (Press back again to exit)"),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.palette_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _titles[nav.currentIndex],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: "बिज़नेस एनालिटिक्स (Business Analytics)",
              icon: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 26),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              ),
            ),
            IconButton(
              tooltip: "वर्चुअल क्लस्टर (Virtual Cluster)",
              icon: const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
              onPressed: () => VirtualClusterDialog.show(context),
            ),
            IconButton(
              tooltip: "व्यापार सहायक (AI Business Assistant)",
              icon: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessAssistantScreen()),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        // The Catalog tab hosts My Products with its own Add button, so the
        // assistant shortcut steps aside while that tab is active.
        floatingActionButton: nav.currentIndex == 1
            ? null
            : FloatingActionButton.extended(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BusinessAssistantScreen()),
                ),
                backgroundColor: AppTheme.primaryTerracotta,
                foregroundColor: Colors.white,
                elevation: 5,
                icon: const Icon(Icons.support_agent_rounded, size: 24),
                label: const Text(
                  "AI व्यापार सहायक",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
        body: IndexedStack(
          index: nav.currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: nav.currentIndex,
            onTap: (index) => context.read<NavigationProvider>().setIndex(index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined, size: 28),
                activeIcon: Icon(Icons.home_rounded, size: 30),
                label: "Home",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_outlined, size: 28),
                activeIcon: Icon(Icons.grid_view_rounded, size: 30),
                label: "Catalog",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.local_shipping_outlined, size: 28),
                activeIcon: Icon(Icons.local_shipping_rounded, size: 30),
                label: "Orders",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded, size: 28),
                activeIcon: Icon(Icons.person_rounded, size: 30),
                label: "Profile",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Buyer Shell ───────────────────────────────────────────────────────────────

class _BuyerMainScreen extends StatefulWidget {
  const _BuyerMainScreen();

  @override
  State<_BuyerMainScreen> createState() => _BuyerMainScreenState();
}

class _BuyerMainScreenState extends State<_BuyerMainScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  static const List<Widget> _screens = [
    BuyerHomeScreen(),
    RfqScreen(),
    BuyerOrdersScreen(),
    ProfileScreen(),
  ];

  static const List<String> _titles = [
    "ShilpSetu • Discover",
    "📋 Request Quote (RFQ)",
    "📦 My Orders",
    "My Profile",
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final name = auth.userModel?.name ?? 'Buyer';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        } else {
          final now = DateTime.now();
          if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
            _lastBackPressTime = now;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Press back again to exit"),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: _currentIndex == 0
            ? null  // BuyerHomeScreen has its own SliverAppBar
            : AppBar(
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shopping_bag_outlined,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _titles[_currentIndex],
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppTheme.primaryTerracotta,
                foregroundColor: Colors.white,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_bag_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              name.split(' ').first,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.search_outlined, size: 28),
                activeIcon: Icon(Icons.search_rounded, size: 30),
                label: "Discover",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.request_quote_outlined, size: 28),
                activeIcon: Icon(Icons.request_quote_rounded, size: 30),
                label: "RFQ",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.local_shipping_outlined, size: 28),
                activeIcon: Icon(Icons.local_shipping_rounded, size: 30),
                label: "Orders",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded, size: 28),
                activeIcon: Icon(Icons.person_rounded, size: 30),
                label: "Profile",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
