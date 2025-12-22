import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/timer_service.dart';
import '../services/alarm_service.dart';

/// 前台服务任务处理类
class ForegroundTaskHandler extends TaskHandler {
  Timer? _updateTimer;
  Timer? _alarmCheckTimer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 初始化服务
    await TimerService().initialize();
    await AlarmService().initialize();

    // 启动定时更新
    _startTimers();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 定期更新通知内容
    _updateNotification();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _updateTimer?.cancel();
    _alarmCheckTimer?.cancel();
  }

  void _startTimers() {
    // 每秒更新计时器和通知
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // 触发计时器更新
      final timers = TimerService().getActiveTimers();
      final activeCount = timers.length;

      // 更新通知
      try {
        FlutterForegroundTask.updateService(
          notificationTitle: 'FireGuard 运行中',
          notificationText: activeCount > 0
              ? '监控中: $activeCount 名消防员'
              : '等待 NFC 刷卡',
        );
      } catch (e) {
        // 忽略更新错误
      }
    });

    // 每秒检查报警
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      try {
        await AlarmService().checkAndTriggerAlarms();
      } catch (e) {
        // 忽略错误
      }
    });
  }

  void _updateNotification() {
    try {
      final timers = TimerService().getActiveTimers();
      final activeCount = timers.length;

      // 更新通知内容
      FlutterForegroundTask.updateService(
        notificationTitle: 'FireGuard 运行中',
        notificationText: activeCount > 0
            ? '监控中: $activeCount 名消防员'
            : '等待 NFC 刷卡',
      );
    } catch (e) {
      // 忽略更新错误
    }
  }
}

/// 前台服务管理类
class ForegroundServiceManager {
  static final ForegroundServiceManager _instance =
      ForegroundServiceManager._internal();
  factory ForegroundServiceManager() => _instance;
  ForegroundServiceManager._internal();

  bool _isRunning = false;

  /// 启动前台服务
  Future<bool> start() async {
    if (_isRunning) {
      return true;
    }

    try {
      // 检查权限
      final hasPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (hasPermission == false) {
        final requestResult =
            await FlutterForegroundTask.requestNotificationPermission();
        if (requestResult == false) {
          return false;
        }
      }

      // 配置前台服务
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'fireguard_service',
          channelName: 'FireGuard 监控服务',
          channelDescription: '持续监控消防员出警状态，确保安全',
          channelImportance: NotificationChannelImportance.HIGH,
          priority: NotificationPriority.HIGH,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          autoRunOnBoot: true,
          allowWakeLock: true,
          allowWifiLock: true,
          eventAction: ForegroundTaskEventAction.repeat(1000),
        ),
      );

      // 启动前台服务
      await FlutterForegroundTask.startService(
        notificationTitle: 'FireGuard 运行中',
        notificationText: '等待 NFC 刷卡',
        callback: startCallback,
      );

      _isRunning = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 停止前台服务
  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    try {
      await FlutterForegroundTask.stopService();
      _isRunning = false;
    } catch (e) {
      // 忽略错误
    }
  }

  /// 更新通知内容
  Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    if (!_isRunning) {
      return;
    }

    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    } catch (e) {
      // 忽略错误
    }
  }

  /// 检查服务是否运行
  bool get isRunning => _isRunning;

  /// 重启服务
  Future<bool> restart() async {
    await stop();
    await Future.delayed(const Duration(milliseconds: 500));
    return await start();
  }
}

/// 前台服务启动回调
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ForegroundTaskHandler());
}
