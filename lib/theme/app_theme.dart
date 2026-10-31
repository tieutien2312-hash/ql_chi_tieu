import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Notifier toàn cục để cập nhật Theme và Font Size toàn ứng dụng
class AppSettingsController extends ChangeNotifier {
  static final AppSettingsController instance = AppSettingsController._();
  AppSettingsController._();

  double _fontSizeScale = 1.0;
  String _accentColorName = 'Cyan';

  double get fontSizeScale => _fontSizeScale;
  String get accentColorName => _accentColorName;

  Color get primaryColor {
    switch (_accentColorName) {
      case 'Indigo':
        return const Color(0xFF6366F1);
      case 'Emerald':
        return AppTheme.successGreen;
      case 'Orange':
        return const Color(0xFFF97316);
      case 'Cyan':
      default:
        return AppTheme.primaryCyan;
    }
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSizeScale = prefs.getDouble('font_size_scale') ?? 1.0;
    _accentColorName = prefs.getString('accent_color') ?? 'Cyan';
    notifyListeners();
  }

  Future<void> updateFontSize(double scale) async {
    _fontSizeScale = scale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size_scale', scale);
  }

  Future<void> updateAccentColor(String colorName) async {
    _accentColorName = colorName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accent_color', colorName);
  }
}

class AppTheme {
  // Brand colors based on reference design
  static const Color primaryCyan = Color(0xFF08C7E8);
  static const Color primaryCyanDark = Color(0xFF06A5C0);
  static const Color backgroundLight = Color(0xFFF4F6FA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF202432);
  static const Color textSecondary = Color(0xFF8A91A2);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);

  static ThemeData get lightTheme {
    final primary = AppSettingsController.instance.primaryColor;
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: surfaceWhite,
        background: backgroundLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceWhite,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceWhite,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
