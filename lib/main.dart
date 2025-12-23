import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_themes.dart';
import 'providers/timer_provider.dart';
import 'providers/alarm_provider.dart';
import 'providers/theme_provider.dart';
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

// 全局主题提供者实例（用于初始化）
ThemeProvider? _themeProvider;

Future<void> _startForegroundService() async {
  final serviceManager = ForegroundServiceManager();
  await serviceManager.start();
}

class FireGuardApp extends StatelessWidget {
  const FireGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 创建主题提供者
    _themeProvider ??= ThemeProvider();
    _themeProvider!.initialize();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TimerProvider()),
        ChangeNotifierProvider(create: (_) => AlarmProvider()),
        ChangeNotifierProvider.value(value: _themeProvider!),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'FireGuard 消防员安全监控',
            theme: themeProvider.theme,
            darkTheme: themeProvider.theme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            home: const HomeScreen(),
            key: ValueKey(themeProvider.currentTheme), // 使用key强制重建以应用新主题
          );
        },
      ),
    );
  }
}
