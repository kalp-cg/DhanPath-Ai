import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// DhanPath Design System - Material 3 Inspired
/// Dark-first design with neon green primary & purple secondary
class AppTheme {
  AppTheme._();

  // ━━━ Spacing Tokens ━━━
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacingXxl = 48;

  // ━━━ Corner Radius Tokens ━━━
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 28;

  // ━━━ Component Dimensions ━━━
  static const double bottomBarHeight = 80;
  static const double buttonHeight = 48;
  static const double minTouchTarget = 48;
  static const double iconSizeSm = 20;
  static const double iconSizeMd = 24;
  static const double iconSizeLg = 40;

  // ━━━ Animation Durations ━━━
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animMedium = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);

  // ━━━ Brand Colors ━━━
  static const Color brandGreen = Color(0xFF2ECC71);
  static const Color brandPurple = Color(0xFFBB86FC);
  static const Color brandDarkCard = Color(0xFF1A1A1A);
  static const Color budgetSuccess = Color(0xFF00C853);

  // ━━━ Light Theme Colors ━━━
  static const Color _lightPrimary = Color(0xFF1B8A4A);
  static const Color _lightOnPrimary = Colors.white;
  static const Color _lightPrimaryContainer = Color(0xFFC8F5D6);
  static const Color _lightOnPrimaryContainer = Color(0xFF002110);
  static const Color _lightSecondary = Color(0xFF7C4DFF);
  static const Color _lightOnSecondary = Colors.white;
  static const Color _lightSecondaryContainer = Color(0xFFE8DEF8);
  static const Color _lightOnSecondaryContainer = Color(0xFF21005E);
  static const Color _lightSurface = Colors.white;
  static const Color _lightBackground = Color(0xFFFAFAFA);
  static const Color _lightError = Color(0xFFBA1A1A);
  static const Color _lightOnSurface = Color(0xFF1C1B1F);
  static const Color _lightOutline = Color(0xFF79747E);
  static const Color _lightSurfaceVariant = Color(0xFFF3F3F3);

  // ━━━ Dark Theme Colors (AMOLED Black + Neon Green) ━━━
  static const Color _darkPrimary = Color(0xFF2ECC71);
  static const Color _darkOnPrimary = Color(0xFF003919);
  static const Color _darkPrimaryContainer = Color(0xFF1A5E30);
  static const Color _darkOnPrimaryContainer = Color(0xFFA5D6A7);
  static const Color _darkSecondary = Color(0xFFBB86FC);
  static const Color _darkOnSecondary = Color(0xFF21005E);
  static const Color _darkSecondaryContainer = Color(0xFF4A148C);
  static const Color _darkOnSecondaryContainer = Color(0xFFE8DEF8);
  static const Color _darkSurface = Color(0xFF1A1A1A);
  static const Color _darkBackground = Color(0xFF000000);
  static const Color _darkError = Color(0xFFFFB4AB);
  static const Color _darkOnSurface = Color(0xFFE6E1E5);
  static const Color _darkOutline = Color(0xFF938F99);
  static const Color _darkSurfaceVariant = Color(0xFF2C2C2E);

  // ━━━ Semantic Colors (Transaction Types) ━━━
  static const Color incomeLight = Color(0xFF2E7D32);
  static const Color incomeDark = Color(0xFF66BB6A);
  static const Color expenseLight = Color(0xFFC62828);
  static const Color expenseDark = Color(0xFFEF5350);
  static const Color creditLight = Color(0xFFE65100);
  static const Color creditDark = Color(0xFFFF9800);
  static const Color transferLight = Color(0xFF6A1B9A);
  static const Color transferDark = Color(0xFFCE93D8);
  static const Color investmentLight = Color(0xFF00695C);
  static const Color investmentDark = Color(0xFF4DB6AC);

  // ━━━ Budget Colors ━━━
  static const Color budgetSafe = Color(0xFF4CAF50);
  static const Color budgetWarning = Color(0xFFFFC107);
  static const Color budgetDanger = Color(0xFFF44336);

  // ━━━ Backward Compatibility Aliases ━━━
  static const Color primaryColor = brandGreen;
  static const Color incomeGreen = Color(0xFF2E7D32);
  static const Color expenseRed = Color(0xFFC62828);
  static const Color neonGreen = brandGreen;
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color pureBlack = Color(0xFF000000);
  static Color get background => _darkBackground;
  static Color get surface => _darkSurface;
  static Color get primary => brandGreen;
  static Color get secondary => brandPurple;
  static Color get accent => brandPurple;
  static Color get inputFill => const Color(0xFFF3F3F3);
  static Color get cardBorder => const Color(0xFFE0E0E0);
  static Color get textDark => _darkOnSurface;
  static Color get textLight => const Color(0xFF79747E);
  static Color get error => _lightError;

  // ━━━ Text Theme Builder ━━━
  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        color: primary,
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.inter(
        color: primary,
        fontWeight: FontWeight.w700,
        fontSize: 28,
        letterSpacing: -0.25,
      ),
      displaySmall: GoogleFonts.inter(
        color: primary,
        fontWeight: FontWeight.w600,
        fontSize: 24,
      ),
      headlineLarge: GoogleFonts.inter(
        color: primary,
        fontWeight: FontWeight.w600,
        fontSize: 22,
      ),
      headlineMedium: GoogleFonts.inter(
        color: primary,
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
      headlineSmall: GoogleFonts.inter(
        color: primary,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      titleLarge: GoogleFonts.inter(
        color: primary,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      titleMedium: GoogleFonts.inter(
        color: primary,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      titleSmall: GoogleFonts.inter(
        color: primary,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      bodyLarge: GoogleFonts.inter(color: primary, fontSize: 16, height: 1.5),
      bodyMedium: GoogleFonts.inter(
        color: secondary,
        fontSize: 14,
        height: 1.43,
      ),
      bodySmall: GoogleFonts.inter(
        color: secondary,
        fontSize: 12,
        height: 1.33,
      ),
      labelLarge: GoogleFonts.inter(
        color: primary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.inter(
        color: secondary,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.inter(
        color: secondary,
        fontWeight: FontWeight.w500,
        fontSize: 11,
        letterSpacing: 0.5,
      ),
    );
  }

  // ━━━━━━━━━━ LIGHT THEME ━━━━━━━━━━
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _lightPrimary,
        onPrimary: _lightOnPrimary,
        primaryContainer: _lightPrimaryContainer,
        onPrimaryContainer: _lightOnPrimaryContainer,
        secondary: _lightSecondary,
        onSecondary: _lightOnSecondary,
        secondaryContainer: _lightSecondaryContainer,
        onSecondaryContainer: _lightOnSecondaryContainer,
        surface: _lightSurface,
        onSurface: _lightOnSurface,
        error: _lightError,
        outline: _lightOutline,
        surfaceContainerHighest: _lightSurfaceVariant,
      ),
      scaffoldBackgroundColor: _lightBackground,
      textTheme: _buildTextTheme(_lightOnSurface, _lightOutline),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingSm,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: _lightOnSurface),
        titleTextStyle: GoogleFonts.inter(
          color: _lightOnSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPrimary,
          foregroundColor: _lightOnPrimary,
          elevation: 0,
          minimumSize: const Size(64, buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLg,
            vertical: spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: _lightPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: _lightError),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingMd,
        ),
        hintStyle: GoogleFonts.inter(color: _lightOutline),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      dividerTheme: const DividerThemeData(
        thickness: 0.5,
        color: Color(0xFFE0E0E0),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        backgroundColor: _lightSurface,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _lightPrimary,
        foregroundColor: _lightOnPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _lightPrimary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return _lightPrimary.withOpacity(0.5);
          return null;
        }),
      ),
    );
  }

  // ━━━━━━━━━━ DARK THEME (AMOLED Black) ━━━━━━━━━━
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        onPrimary: _darkOnPrimary,
        primaryContainer: _darkPrimaryContainer,
        onPrimaryContainer: _darkOnPrimaryContainer,
        secondary: _darkSecondary,
        onSecondary: _darkOnSecondary,
        secondaryContainer: _darkSecondaryContainer,
        onSecondaryContainer: _darkOnSecondaryContainer,
        surface: _darkSurface,
        onSurface: _darkOnSurface,
        error: _darkError,
        outline: _darkOutline,
        surfaceContainerHighest: _darkSurfaceVariant,
      ),
      scaffoldBackgroundColor: _darkBackground,
      textTheme: _buildTextTheme(_darkOnSurface, _darkOutline),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingSm,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _darkBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: _darkOnSurface),
        titleTextStyle: GoogleFonts.inter(
          color: _darkOnSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: _darkOnPrimary,
          elevation: 0,
          minimumSize: const Size(64, buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLg,
            vertical: spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: _darkPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: _darkError),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingMd,
        ),
        hintStyle: GoogleFonts.inter(color: _darkOutline),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      dividerTheme: DividerThemeData(
        thickness: 0.5,
        color: Colors.white.withOpacity(0.08),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        backgroundColor: _darkSurface,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        backgroundColor: _darkSurface,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _darkPrimary,
        foregroundColor: _darkOnPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _darkPrimary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return _darkPrimary.withOpacity(0.5);
          return null;
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _darkSurface,
        selectedItemColor: _darkPrimary,
        unselectedItemColor: Colors.white.withOpacity(0.5),
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
    );
  }
}

/// Extension to access semantic transaction colors from theme
extension ThemeColorExtensions on ColorScheme {
  Color get income => brightness == Brightness.dark
      ? AppTheme.incomeDark
      : AppTheme.incomeLight;
  Color get expense => brightness == Brightness.dark
      ? AppTheme.expenseDark
      : AppTheme.expenseLight;
  Color get credit => brightness == Brightness.dark
      ? AppTheme.creditDark
      : AppTheme.creditLight;
  Color get transfer => brightness == Brightness.dark
      ? AppTheme.transferDark
      : AppTheme.transferLight;
  Color get investment => brightness == Brightness.dark
      ? AppTheme.investmentDark
      : AppTheme.investmentLight;
  Color get success => brightness == Brightness.dark
      ? AppTheme.incomeDark
      : AppTheme.incomeLight;
  Color get warning => brightness == Brightness.dark
      ? AppTheme.budgetWarning
      : AppTheme.budgetWarning;
}
