import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Legacy & widget color aliases for backward compatibility across panes
class NxColors {
  static const Color bg = Color(0xFF08080C);
  static const Color card = Color(0xFF10131B);
  static const Color cardRaised = Color(0xFF161B26);
  static const Color field = Color(0xFF161A24);
  static const Color line = Color(0xFF1E2536);
  static const Color brand = Color(0xFF4F8BFF);
  static const Color brandPurple = Color(0xFF8B5CF6);
  static const Color brandInk = Colors.white;
  static const Color text = Color(0xFFF1F5F9);
  static const Color muted = Color(0xFF94A3B8);
  static const Color faint = Color(0xFF475569);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

class NexoraTheme {
  // Deep OLED Glassmorphic Canvas
  static const Color scaffold = Color(0xFF08080C);
  static const Color card = Color(0xFF10131B);
  static const Color cardRaised = Color(0xFF161B26);
  static const Color input = Color(0xFF161A24);
  static const Color border = Color(0xFF1E2536);
  static const Color borderSubtle = Color(0xFF283144);
  static const Color primary = Color(0xFF4F8BFF);
  static const Color accent = Color(0xFF8B5CF6);

  // Typography & Status Tokens
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Superadmin & Approver Signature Spectrum
  static const List<String> adminColorHexOptions = [
    '#3B82F6', // Verified Blue (Primary & Professional)
    '#8B5CF6', // Electric Purple
    '#F59E0B', // Amber Gold
    '#10B981', // Emerald Mint
    '#06B6D4', // Cyan Sky
    '#EF4444', // Crimson Flame
  ];

  static Color parseHex(String? hex, {Color fallback = primary}) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final clean = hex.replaceAll('#', '').trim();
      final fullHex = clean.length == 6 ? 'FF$clean' : clean;
      return Color(int.parse(fullHex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  /// Display typography for titles, hero headers, and modal bars
  static TextStyle headingStyle({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
    double letterSpacing = -0.3,
  }) {
    return GoogleFonts.syne(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Body typography for general UI, lists, and paragraphs
  static TextStyle bodyStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textPrimary,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  /// Monospace typography for technical stamps, registration numbers, and dates
  static TextStyle monoStyle({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color color = primary,
    double letterSpacing = 0.5,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      colorScheme: const ColorScheme.dark(
        surface: card,
        primary: primary,
        secondary: accent,
        onPrimary: Colors.white,
        onSurface: textPrimary,
        outline: border,
        error: error,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.syne(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 32, letterSpacing: -0.8),
        displayMedium: GoogleFonts.syne(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 26, letterSpacing: -0.6),
        displaySmall: GoogleFonts.syne(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.4),
        headlineMedium: GoogleFonts.syne(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: -0.3),
        titleLarge: GoogleFonts.syne(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.2),
        titleMedium: GoogleFonts.syne(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: -0.1),
        titleSmall: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
        bodyLarge: GoogleFonts.inter(color: textPrimary, fontSize: 15, height: 1.45),
        bodyMedium: GoogleFonts.inter(color: textPrimary, fontSize: 13.5, height: 1.4),
        bodySmall: GoogleFonts.inter(color: textSecondary, fontSize: 12),
        labelLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
        labelMedium: GoogleFonts.inter(color: textSecondary, fontWeight: FontWeight.w500, fontSize: 11),
        labelSmall: GoogleFonts.inter(color: textMuted, fontWeight: FontWeight.w500, fontSize: 10),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.syne(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: input,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 13.5),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: border),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffold,
        indicatorColor: primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(color: primary, fontWeight: FontWeight.w700, fontSize: 11);
          }
          return GoogleFonts.inter(color: textMuted, fontWeight: FontWeight.w500, fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 22);
          }
          return const IconThemeData(color: textMuted, size: 22);
        }),
      ),
    );
  }
}
