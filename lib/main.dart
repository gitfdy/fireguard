import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_themes.dart';
import 'providers/timer_provider.dart';
import 'providers/alarm_provider.dart';
import 'services/database_service.dart';
import 'services/timer_service.dart';
import 'services/alarm_service.dart';
import 'services/settings_service.dart';
import 'services/foreground_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化服务
  await _initializeServices();

  // 启动前台服务
  await _startForegroundService();

  runApp(const FireGuardApp());
}

Future<void> _initializeServices() async {
  // 初始化数据库
  await DatabaseService().database;

  // 初始化设置服务
  await SettingsService().initialize();

  // 初始化计时器服务
  final timerService = TimerService();
  await timerService.initialize();

  // 从设置加载倒计时时长
  final settingsService = SettingsService();
  final duration = await settingsService.getTimerDuration();
  timerService.setTimerDuration(duration);

  // 初始化报警服务
  await AlarmService().initialize();

  // 启动定时检查报警（前台服务中也会执行，这里作为备用）
  Timer.periodic(const Duration(seconds: 1), (timer) {
    AlarmService().checkAndTriggerAlarms();
  });
}

Future<void> _startForegroundService() async {
  final serviceManager = ForegroundServiceManager();
  await serviceManager.start();
}

class FireGuardApp extends StatefulWidget {
  const FireGuardApp({super.key});

  @override
  State<FireGuardApp> createState() => _FireGuardAppState();
}

class _FireGuardAppState extends State<FireGuardApp> {
  AppThemeType _currentTheme = AppThemeType.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final settingsService = SettingsService();
    final themeType = await settingsService.getThemeType();
    if (mounted) {
      setState(() {
        _currentTheme = themeType;
      });
    }
  }

  void _updateTheme(AppThemeType themeType) {
    setState(() {
      _currentTheme = themeType;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TimerProvider()),
        ChangeNotifierProvider(create: (_) => AlarmProvider()),
      ],
      child: MaterialApp(
        title: 'FireGuard 消防员安全监控',
        theme: AppThemes.getTheme(_currentTheme),
        darkTheme: AppThemes.getTheme(_currentTheme),
        themeMode:
            _currentTheme == AppThemeType.light ||
                _currentTheme == AppThemeType.highContrastLight
            ? ThemeMode.light
            : ThemeMode.dark,
        debugShowCheckedModeBanner: false,
        home: HomeScreen(onThemeChanged: _updateTheme),
        key: ValueKey(_currentTheme), // 使用key强制重建以应用新主题
      ),
    );
  }
}
