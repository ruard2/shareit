// lib/theme.dart  — Flutter 3.32-compatible Apple HIG design tokens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iOS / Apple HIG design tokens
class AppleColors {
  AppleColors._();

  // System colours – light mode
  static const systemBlue   = Color(0xFF007AFF);
  static const systemGreen  = Color(0xFF34C759);
  static const systemRed    = Color(0xFFFF3B30);
  static const systemOrange = Color(0xFFFF9500);
  static const systemGray   = Color(0xFF8E8E93);
  static const systemGray2  = Color(0xFFAEAEB2);
  static const systemGray3  = Color(0xFFC7C7CC);
  static const systemGray4  = Color(0xFFD1D1D6);
  static const systemGray5  = Color(0xFFE5E5EA);
  static const systemGray6  = Color(0xFFF2F2F7);

  // System colours – dark mode
  static const systemBlueDark   = Color(0xFF0A84FF);
  static const systemGreenDark  = Color(0xFF30D158);
  static const systemRedDark    = Color(0xFFFF453A);
  static const systemOrangeDark = Color(0xFFFF9F0A);
  static const systemGray2Dark  = Color(0xFF636366);
  static const systemGray3Dark  = Color(0xFF48484A);
  static const systemGray4Dark  = Color(0xFF3A3A3C);
  static const systemGray5Dark  = Color(0xFF2C2C2E);
  static const systemGray6Dark  = Color(0xFF1C1C1E);

  // Backgrounds
  static const backgroundLight = Color(0xFFF2F2F7);
  static const backgroundDark  = Color(0xFF000000);
  static const surfaceLight     = Color(0xFFFFFFFF);
  static const surfaceDark      = Color(0xFF1C1C1E);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark()  => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    final primary    = dark ? AppleColors.systemBlueDark  : AppleColors.systemBlue;
    final secondary  = dark ? AppleColors.systemGreenDark  : AppleColors.systemGreen;
    final error      = dark ? AppleColors.systemRedDark    : AppleColors.systemRed;
    final background = dark ? AppleColors.backgroundDark   : AppleColors.backgroundLight;
    final surface    = dark ? AppleColors.surfaceDark      : AppleColors.surfaceLight;
    // "surfaceVariant" replacement in 3.32 = surfaceContainerHighest
    final surfHigh   = dark ? AppleColors.systemGray5Dark  : AppleColors.systemGray6;
    final onSurface  = dark ? Colors.white                 : Colors.black;
    final onSurfVar  = dark ? AppleColors.systemGray2Dark  : AppleColors.systemGray;
    final divider    = dark ? AppleColors.systemGray4Dark  : AppleColors.systemGray5;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: dark ? const Color(0xFF003380) : const Color(0xFFD1E4FF),
      onPrimaryContainer: dark ? Colors.white : const Color(0xFF001849),
      secondary: secondary,
      onSecondary: Colors.white,
      secondaryContainer: dark ? const Color(0xFF003A1C) : const Color(0xFFCCF0D8),
      onSecondaryContainer: dark ? Colors.white : const Color(0xFF00210D),
      tertiary: dark ? AppleColors.systemOrangeDark : AppleColors.systemOrange,
      onTertiary: Colors.white,
      tertiaryContainer: dark ? const Color(0xFF3A2000) : const Color(0xFFFFDCC2),
      onTertiaryContainer: dark ? Colors.white : const Color(0xFF2B1700),
      error: error,
      onError: Colors.white,
      errorContainer: dark ? const Color(0xFF500000) : const Color(0xFFFFDAD6),
      onErrorContainer: dark ? Colors.white : const Color(0xFF410002),
      // Flutter 3.32+: use surface/onSurface; background is deprecated
      surface: surface,
      onSurface: onSurface,
      // surfaceContainerHighest replaces the old surfaceVariant
      surfaceContainerHighest: surfHigh,
      onSurfaceVariant: onSurfVar,
      outline: divider,
      outlineVariant: divider,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: dark ? Colors.white : const Color(0xFF1C1C1E),
      onInverseSurface: dark ? Colors.black : Colors.white,
      inversePrimary: dark ? AppleColors.systemBlue : AppleColors.systemBlueDark,
    );

    final tt = _buildTextTheme(onSurface, onSurfVar, primary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: tt,
      scaffoldBackgroundColor: background,

      // --- AppBar (iOS navigation bar) ---
      appBarTheme: AppBarTheme(
        backgroundColor: dark
            ? AppleColors.surfaceDark.withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.94),
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: divider,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: onSurface,
        ),
        iconTheme: IconThemeData(color: primary, size: 22),
        actionsIconTheme: IconThemeData(color: primary, size: 22),
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // --- Elevated Button ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: dark ? AppleColors.systemGray4Dark : AppleColors.systemGray5,
          disabledForegroundColor: onSurfVar,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size.fromHeight(50),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),

      // --- Text Button ---
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
      ),

      // --- Outlined Button ---
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size.fromHeight(50),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),

      // --- Card ---
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
      ),

      // --- Input ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppleColors.systemGray5Dark : AppleColors.systemGray6,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: onSurfVar, fontSize: 17),
        labelStyle: TextStyle(color: onSurfVar, fontSize: 15, fontWeight: FontWeight.w400),
        floatingLabelStyle: TextStyle(color: primary, fontSize: 13),
      ),

      // --- Switch (iOS green toggle) ---
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return dark ? AppleColors.systemGreenDark : AppleColors.systemGreen;
          }
          return dark ? AppleColors.systemGray4Dark : AppleColors.systemGray4;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // --- Divider ---
      dividerTheme: DividerThemeData(
        thickness: 0.5,
        space: 0,
        color: divider,
      ),

      // --- ListTile ---
      listTileTheme: ListTileThemeData(
        tileColor: surface,
        shape: const RoundedRectangleBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
        iconColor: primary,
        textColor: onSurface,
        dense: false,
      ),

      // --- Icons ---
      iconTheme: IconThemeData(color: primary, size: 24),

      // --- ProgressIndicator ---
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),

      // --- Chip ---
      chipTheme: ChipThemeData(
        backgroundColor: surfHigh,
        selectedColor: primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(fontSize: 14, color: onSurface),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // --- SnackBar ---
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // --- Dialog ---
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        contentTextStyle: TextStyle(fontSize: 15, color: onSurface),
      ),

      // --- BottomSheet ---
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(Color label, Color secondary, Color primary) {
    return TextTheme(
      displayLarge:  _ts(34, FontWeight.w700, label,     ls: -0.5),
      displayMedium: _ts(28, FontWeight.w700, label,     ls: -0.4),
      displaySmall:  _ts(22, FontWeight.w700, label,     ls: -0.3),
      headlineLarge:  _ts(20, FontWeight.w600, label,    ls: -0.2),
      headlineMedium: _ts(18, FontWeight.w600, label,    ls: -0.2),
      headlineSmall:  _ts(17, FontWeight.w600, label,    ls: -0.1),
      titleLarge:  _ts(17, FontWeight.w600, label,       ls: -0.1),
      titleMedium: _ts(16, FontWeight.w500, label,       ls: -0.1),
      titleSmall:  _ts(15, FontWeight.w500, label),
      bodyLarge:  _ts(17, FontWeight.w400, label),
      bodyMedium: _ts(15, FontWeight.w400, label),
      bodySmall:  _ts(13, FontWeight.w400, secondary),
      labelLarge:  _ts(17, FontWeight.w600, primary),
      labelMedium: _ts(15, FontWeight.w500, label),
      labelSmall:  _ts(13, FontWeight.w500, secondary, ls: 0.1),
    );
  }

  static TextStyle _ts(
    double size,
    FontWeight weight,
    Color color, {
    double ls = 0,
    double height = 1.4,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: ls,
        height: height,
      );
}
