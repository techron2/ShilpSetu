import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'catalog_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'artisan/business_assistant_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  final List<Widget> _screens = const [
    HomeScreen(),
    CatalogScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  final List<String> _titles = const [
    "शिल्पसेतु • होम (Home)",
    "शिल्प सूची (Catalog)",
    "ऑर्डर्स व डिलीवरी (Orders)",
    "शिल्पकार प्रोफ़ाइल (Profile)",
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();

    return Scaffold(
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
            tooltip: "व्यापार सहायक (AI Business Assistant)",
            icon: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessAssistantScreen()),
              );
            },
          ),
          IconButton(
            tooltip: "वॉयस गाइड (Voice Guide)",
            icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 26),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("🔊 ऑडियो सहायता सक्रिय है (Audio Guide Active)"),
                  backgroundColor: AppTheme.darkIndigo,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BusinessAssistantScreen()),
          );
        },
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
    );
  }
}
