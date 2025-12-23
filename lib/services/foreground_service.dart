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
    // 注意：在前台服务中，报警检查会继续运行，即使App在后台
    // 报警音、震动、拨打电话等操作也会在前台服务中执行
    // 
    // 重要说明：
    // 1. 倒计时计算基于绝对时间，即使Timer暂停，时间计算仍然准确
    // 2. 报警检查在前台服务中每秒执行，可以检测超时
    // 3. 报警音、震动通过平台通道实现，可以在后台运行
    // 4. 自动拨打电话通过url_launcher实现，可以在后台运行
    // 5. 延迟拨号定时器在AlarmService中创建，前台服务中的AlarmService实例会继续运行
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      try {
        // 检查并触发报警
        // 这个操作会在前台服务中执行，确保后台也能正常工作
        // AlarmService在前台服务的isolate中初始化，所以它的Timer会继续运行
        await AlarmService().checkAndTriggerAlarms();
        
        // 注意：
        // - 报警音、震动、拨打电话等操作在AlarmService中执行
        // - 这些操作通过平台通道或包实现，可以在后台运行
        // - 延迟拨号定时器(_callDelayTimer)也会在前台服务中继续运行
      } catch (e) {
        // 忽略错误，确保服务继续运行
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
