import 'package:flutter/material.dart';

/// Accessible, culturally resonant theme system for ShilpSetu.
/// Designed specifically for marginalized rural artisans with high contrast,
/// large touch targets (>= 48dp), and a warm Indian handicraft palette.
class AppTheme {
  // Brand Color Palette
  static const Color primaryTerracotta = Color(0xFFB84A39); // Indian clay/terracotta
  static const Color secondaryOchre = Color(0xFFD48B38);    // Warm turmeric/ochre
  static const Color darkIndigo = Color(0xFF1B2A4A);        // Deep indigo for text & contrast
  static const Color bgParchment = Color(0xFFFAF7F2);       // Low-glare warm off-white
  static const Color cardBg = Color(0xFFFFFFFF);            // Clean white
  static const Color borderGrey = Color(0xFFE5DFD7);        // Subtle soft border
  static const Color successGreen = Color(0xFF2E7D32);      // Natural leaf green
  static const Color inTransitBlue = Color(0xFF1976D2);     // Delivery blue
  static const Color warningRed = Color(0xFFD32F2F);        // Warning/error red

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTerracotta,
        primary: primaryTerracotta,
        secondary: secondaryOchre,
        surface: bgParchment,
        onSurface: darkIndigo,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: bgParchment,
      
      // Accessible AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryTerracotta,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),

      // Accessible Card Theme
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderGrey, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      // Large Tap Target Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTerracotta,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54), // >= 48dp standard
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTerracotta,
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: primaryTerracotta, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Accessible High-Contrast Typography
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: darkIndigo,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkIndigo,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: darkIndigo,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: darkIndigo,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Color(0xFF4A5568),
        ),
      ),

      // Accessible Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryTerracotta,
        unselectedItemColor: Color(0xFF718096),
        selectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        showUnselectedLabels: true,
      ),
    );
  }
}
