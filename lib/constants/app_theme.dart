import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 应用主题配置
class AppTheme {
  /// 暗色主题（根据用户偏好，始终使用暗色）
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryRed,
        secondary: AppColors.warningOrange,
        error: AppColors.timeoutRed,
        surface: AppColors.darkBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        onSurface: AppColors.textPrimaryDark,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryDark,
          fontFamily: 'Roboto',
        ),
        displayMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryDark,
          fontFamily: 'Roboto',
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimaryDark,
          fontFamily: 'Roboto',
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          color: AppColors.textPrimaryDark,
          fontFamily: 'Roboto',
        ),
        bodyMedium: TextStyle(
          fontSize: 18,
          color: AppColors.textSecondaryDark,
          fontFamily: 'Roboto',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          minimumSize: const Size(120, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  /// 字体大小常量
  static const double fontSizeTitle = 24.0;
  static const double fontSizeName = 20.0;
  static const double fontSizeTimer = 36.0;
  static const double fontSizeBody = 18.0;
}

