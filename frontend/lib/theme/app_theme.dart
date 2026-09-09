import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Accessible, culturally resonant theme system for ShilpSetu.
/// Designed specifically for marginalized rural artisans with high contrast,
/// large touch targets (>= 48dp), and a warm Indian handicraft palette.
class AppTheme {
  // ── Brand Color Palette ───────────────────────────────────────────────────
  static const Color primaryTerracotta = Color(0xFFB84A39); // Indian clay/terracotta
  static const Color secondaryOchre    = Color(0xFFD48B38); // Warm turmeric/ochre
  static const Color darkIndigo        = Color(0xFF1B2A4A); // Deep indigo for text & contrast
  static const Color bgParchment       = Color(0xFFFAF7F2); // Low-glare warm off-white
  static const Color cardBg            = Color(0xFFFFFFFF); // Clean white
  static const Color borderGrey        = Color(0xFFE5DFD7); // Subtle soft border
  static const Color successGreen      = Color(0xFF2E7D32); // Natural leaf green
  static const Color inTransitBlue     = Color(0xFF1976D2); // Delivery blue
  static const Color warningRed        = Color(0xFFD32F2F); // Warning/error red

  // ── Added tokens ─────────────────────────────────────────────────────────
  static const Color warningAmber   = Color(0xFFF59E0B); // Pending / attention
  static const Color surfaceVariant = Color(0xFFF5F0EB); // Slightly warmer surface for sections

  static ThemeData get lightTheme {
    final base = ThemeData(useMaterial3: true);

    // Outfit works great for both Latin & Devanagari scripts
    final outfitTextTheme = GoogleFonts.outfitTextTheme(base.textTheme);

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTerracotta,
        primary: primaryTerracotta,
        secondary: secondaryOchre,
        surface: bgParchment,
        onSurface: darkIndigo,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: bgParchment,

      // ── Typography ────────────────────────────────────────────────────────
      textTheme: outfitTextTheme.copyWith(
        headlineMedium: GoogleFonts.outfit(
          fontSize: 24, fontWeight: FontWeight.w800, color: darkIndigo,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.w700, color: darkIndigo,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 17, fontWeight: FontWeight.w600, color: darkIndigo,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w500, color: darkIndigo,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF4A5568),
        ),
        labelLarge: GoogleFonts.outfit(
          fontSize: 13, fontWeight: FontWeight.w700, color: darkIndigo,
        ),
        labelSmall: GoogleFonts.outfit(
          fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280),
        ),
      ),

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: primaryTerracotta,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
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

      // ── Elevated Buttons ──────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTerracotta,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),

      // ── Outlined Buttons ──────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTerracotta,
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: primaryTerracotta, width: 1.8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Text Buttons ──────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTerracotta,
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),

      // ── Global Input Decoration ───────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.outfit(
          fontSize: 14, color: const Color(0xFF9CA3AF),
        ),
        labelStyle: GoogleFonts.outfit(
          fontSize: 14, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.outfit(
          fontSize: 13, color: primaryTerracotta, fontWeight: FontWeight.w600,
        ),
        prefixIconColor: primaryTerracotta,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTerracotta, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: warningRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: warningRed, width: 2),
        ),
        errorStyle: GoogleFonts.outfit(
          fontSize: 12, color: warningRed, fontWeight: FontWeight.w500,
        ),
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: primaryTerracotta,
        disabledColor: borderGrey,
        labelStyle: GoogleFonts.outfit(
          fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF4B5563),
        ),
        secondaryLabelStyle: GoogleFonts.outfit(
          fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderGrey),
        ),
        elevation: 0,
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: borderGrey,
        thickness: 1,
        space: 1,
      ),

      // ── Bottom Navigation ─────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryTerracotta,
        unselectedItemColor: const Color(0xFF718096),
        selectedLabelStyle: GoogleFonts.outfit(
          fontSize: 13, fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontSize: 12, fontWeight: FontWeight.w600,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        showUnselectedLabels: true,
      ),

      // ── Snackbar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  // ── Shared helper: secondary (dark indigo) elevated button style ──────────
  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: darkIndigo,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 52),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
    elevation: 0,
  );

  // ── Shared helper: success (green) elevated button style ─────────────────
  static ButtonStyle get successButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: successGreen,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 52),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
    elevation: 0,
  );

  // ── Shared helper: danger (red) outlined button style ────────────────────
  static ButtonStyle get dangerOutlinedButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: warningRed,
    minimumSize: const Size(double.infinity, 50),
    side: const BorderSide(color: warningRed, width: 1.8),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
  );
}
