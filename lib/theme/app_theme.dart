import 'package:flutter/material.dart';
import 'theme_manager.dart';

class AppTheme {
  // School Color Palette
  static const Color primaryPurple   = Color(0xFF6A0DAD); // Deep School Purple
  static const Color secondaryPurple = Color(0xFF9B59B6); // Mid Purple
  static const Color lilac           = Color(0xFFD7B4F3); // Lilac
  static const Color primaryYellow   = Color(0xFFFFD700); // School Gold/Yellow
  static const Color accentYellow    = Color(0xFFFFF176); // Light Yellow
  static const Color black           = Color(0xFF1A1A1A); // Near Black
  static const Color white           = Color(0xFFFFFFFF);

  // Semantic Colors
  static const Color success  = Color(0xFF27AE60);
  static const Color warning  = Color(0xFFF39C12);
  static const Color error    = Color(0xFFE74C3C);
  static const Color info     = Color(0xFF2980B9);

  // Neutral
  static Color get backgroundLight => ThemeManager.isDarkMode ? const Color(0xFF12121E) : const Color(0xFFF8F5FF);
  static Color get backgroundWhite => ThemeManager.isDarkMode ? const Color(0xFF1E1E2E) : const Color(0xFFFFFFFF);
  static Color get textPrimary     => ThemeManager.isDarkMode ? const Color(0xFFF1F1F1) : const Color(0xFF1A1A1A);
  static Color get textSecondary   => ThemeManager.isDarkMode ? const Color(0xFFA0A0B0) : const Color(0xFF6B6B6B);
  static Color get dividerColor    => ThemeManager.isDarkMode ? const Color(0xFF2E2E3E) : const Color(0xFFE8E0F0);
  static Color get cardBackground  => ThemeManager.isDarkMode ? const Color(0xFF1E1E2E) : const Color(0xFFFFFFFF);

  // RIASEC type colors (matching Holland Hexagon: R=Red, I=Blue, A=Green, S=Purple, E=Orange, C=Yellow)
  static const Color riasecR = Color(0xFFE53935); // Realistic (Red / Doers)
  static const Color riasecI = Color(0xFF1E88E5); // Investigative (Blue / Thinkers)
  static const Color riasecA = Color(0xFF43A047); // Artistic (Green / Creators)
  static const Color riasecS = Color(0xFF8E44AD); // Social (Purple / Helpers)
  static const Color riasecE = Color(0xFFE67E22); // Enterprising (Orange / Persuaders)
  static const Color riasecC = Color(0xFFEAB308); // Conventional (Bright Sunflower Yellow / Organizers)

  // CDSES Subscale Colors (5 distinct hues: no duplicate greens)
  static const Color cdsesSA = Color(0xFF8B5CF6); // Self-Appraisal (Violet / Purple)
  static const Color cdsesOI = Color(0xFF0EA5E9); // Occupational Information (Sky Blue / Cyan)
  static const Color cdsesGS = Color(0xFF2563EB); // Goal Selection (Royal Blue)
  static const Color cdsesPL = Color(0xFFF59E0B); // Planning (Amber / Orange)
  static const Color cdsesPS = Color(0xFF10B981); // Problem Solving (Emerald Green)

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPurple,
        brightness: Brightness.light,
        primary: primaryPurple,
        secondary: primaryYellow,
        surface: backgroundWhite,
        onPrimary: white,
        onSecondary: black,
      ),
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: primaryPurple,
        foregroundColor: white,
        titleTextStyle: TextStyle(
          color: white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: white),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: cardBackground,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryPurple,
          side: const BorderSide(color: primaryPurple),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primaryPurple;
            return white;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return white;
            return primaryPurple;
          }),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
        filled: true,
        fillColor: backgroundWhite,
        prefixIconColor: primaryPurple,
        labelStyle: TextStyle(color: textSecondary),
        floatingLabelStyle: const TextStyle(color: primaryPurple),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lilac.withOpacity(0.3),
        labelStyle: const TextStyle(color: primaryPurple),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryPurple,
        linearTrackColor: dividerColor,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPurple,
        brightness: Brightness.dark,
        primary: primaryPurple,
        secondary: primaryYellow,
        surface: const Color(0xFF1E1E2E),
        onPrimary: white,
        onSecondary: black,
      ),
      scaffoldBackgroundColor: const Color(0xFF12121E),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Color(0xFF1A1A2A),
        foregroundColor: white,
        titleTextStyle: TextStyle(
          color: white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: white),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: const Color(0xFF1E1E2E),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lilac,
          side: const BorderSide(color: lilac),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primaryPurple;
            return const Color(0xFF1E1E2E);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return white;
            return primaryPurple;
          }),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFF1E1E2E),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2E2E3E)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2E2E3E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFF1E1E2E),
        prefixIconColor: primaryPurple,
        labelStyle: const TextStyle(color: Color(0xFF8E8E9F)),
        floatingLabelStyle: const TextStyle(color: primaryPurple),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryPurple.withOpacity(0.3),
        labelStyle: const TextStyle(color: white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryPurple,
        linearTrackColor: Color(0xFF2E2E3E),
      ),
    );
  }

  // Helper: Get RIASEC type color
  static Color riasecColor(String type) {
    switch (type.toUpperCase()) {
      case 'R': return riasecR;
      case 'I': return riasecI;
      case 'A': return riasecA;
      case 'S': return riasecS;
      case 'E': return riasecE;
      case 'C': return riasecC;
      default:  return primaryPurple;
    }
  }

  // Helper: Get CDSES subscale color
  static Color cdsesColor(String code) {
    switch (code.toUpperCase()) {
      case 'SA': return cdsesSA;
      case 'OI': return cdsesOI;
      case 'GS': return cdsesGS;
      case 'PL': return cdsesPL;
      case 'PS': return cdsesPS;
      default:   return primaryPurple;
    }
  }

  // Helper: Get Senior High School Academic Strand color
  static Color strandColor(String strand) {
    final s = strand.toUpperCase();
    if (s.contains('STEM')) {
      return const Color(0xFF0284C7); // Electric Blue (Science, Tech, Engineering, Math)
    } else if (s.contains('ABM')) {
      return const Color(0xFF10B981); // Emerald Green (Accountancy, Business, Management)
    } else if (s.contains('HUMSS')) {
      return const Color(0xFFE11D48); // Rose / Coral (Humanities, Social Sciences)
    } else if (s.contains('GAS') || s.contains('GENERAL')) {
      return const Color(0xFF8B5CF6); // Deep Violet (General Academic Strand)
    } else if (s.contains('TVL') || s.contains('VOCATIONAL') || s.contains('LIVELIHOOD')) {
      return const Color(0xFFF59E0B); // Amber / Warm Orange (Technical-Vocational)
    } else if (s.contains('ICT')) {
      return const Color(0xFF06B6D4); // Cyan (Information & Communications Tech)
    } else if (s.contains('ARTS')) {
      return const Color(0xFFEC4899); // Fuchsia / Pink (Arts & Design Track)
    } else if (s.contains('SPORTS')) {
      return const Color(0xFF84CC16); // Lime Green (Sports Track)
    }
    return primaryPurple;
  }

  // Helper: Normalize strand name to standard full school title
  static String normalizeStrand(String strand) {
    final s = strand.trim();
    final u = s.toUpperCase();
    if (u.contains('STEM')) {
      return 'STEM (Science, Technology, Engineering, Mathematics)';
    } else if (u.contains('ABM')) {
      return 'ABM (Accountancy, Business, Management)';
    } else if (u.contains('HUMSS')) {
      return 'HUMSS (Humanities and Social Sciences)';
    } else if (u.contains('GAS') || u.contains('GENERAL')) {
      return 'GAS (General Academic Strand)';
    } else if (u.contains('TVL') || u.contains('VOCATIONAL') || u.contains('LIVELIHOOD')) {
      return 'TVL (Technical-Vocational-Livelihood)';
    } else if (u.contains('ICT')) {
      return 'ICT (Information and Communications Technology)';
    } else if (u.contains('ARTS')) {
      return 'Arts and Design Track';
    } else if (u.contains('SPORTS')) {
      return 'Sports Track';
    }
    return s.isNotEmpty ? s : 'Unassigned';
  }

  // Helper: Get Top Recommended Course Cluster color (Thematic Domain Colors)
  static Color clusterColor(String clusterName) {
    final c = clusterName.toLowerCase();
    if (c.contains('tech') || c.contains('engine') || c.contains('comput')) {
      return const Color(0xFF2563EB); // Royal Blue
    } else if (c.contains('business') || c.contains('account') || c.contains('manage') || c.contains('finance')) {
      return const Color(0xFF059669); // Emerald Green
    } else if (c.contains('humanit') || c.contains('social') || c.contains('law') || c.contains('crimin')) {
      return const Color(0xFFE11D48); // Rose / Crimson
    } else if (c.contains('health') || c.contains('nurs') || c.contains('medic') || c.contains('allied')) {
      return const Color(0xFF0D9488); // Medical Teal
    } else if (c.contains('media') || c.contains('creative') || c.contains('art') || c.contains('communicat')) {
      return const Color(0xFF9333EA); // Vibrant Violet / Magenta
    } else if (c.contains('educat') || c.contains('psycholog') || c.contains('service')) {
      return const Color(0xFFF59E0B); // Amber / Warm Orange
    } else if (c.contains('agri') || c.contains('environ') || c.contains('natur')) {
      return const Color(0xFF65A30D); // Olive / Forest Green
    } else if (c.contains('science') || c.contains('math') || c.contains('research')) {
      return const Color(0xFF0284C7); // Tech Blue / Cyan
    }
    return primaryPurple;
  }


  // Helper: Get RIASEC type full name
  static String riasecName(String type) {
    switch (type.toUpperCase()) {
      case 'R': return 'Realistic';
      case 'I': return 'Investigative';
      case 'A': return 'Artistic';
      case 'S': return 'Social';
      case 'E': return 'Enterprising';
      case 'C': return 'Conventional';
      default:  return type;
    }
  }

  // Helper: Get RIASEC type descriptor
  static String riasecDescriptor(String type) {
    switch (type.toUpperCase()) {
      case 'R': return 'Doers';
      case 'I': return 'Thinkers';
      case 'A': return 'Creators';
      case 'S': return 'Helpers';
      case 'E': return 'Persuaders';
      case 'C': return 'Organizers';
      default:  return '';
    }
  }
}