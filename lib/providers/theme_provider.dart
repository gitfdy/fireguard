import 'package:flutter/material.dart';
import '../constants/app_themes.dart';
import '../services/settings_service.dart';

/// 主题提供者
class ThemeProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();
  AppThemeType _currentTheme = AppThemeType.dark;

  AppThemeType get currentTheme => _currentTheme;

  ThemeData get theme => AppThemes.getTheme(_currentTheme);

  ThemeMode get themeMode =>
      _currentTheme == AppThemeType.light ||
              _currentTheme == AppThemeType.highContrastLight
          ? ThemeMode.light
          : ThemeMode.dark;

  /// 初始化主题
  Future<void> initialize() async {
    _currentTheme = await _settingsService.getThemeType();
    notifyListeners();
  }

  /// 更新主题
  Future<void> setTheme(AppThemeType themeType) async {
    if (_currentTheme == themeType) return;

    _currentTheme = themeType;
    await _settingsService.setThemeType(themeType);
    notifyListeners();
  }
}

