import 'dart:async';
import '../models/timer_record.dart';
import '../models/history_record.dart';
import '../constants/app_constants.dart';
import 'database_service.dart';

/// 计时器服务
class TimerService {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  final Map<String, TimerRecord> _activeTimers = {};
  Timer? _updateTimer;
  final List<Function(List<TimerRecord>)> _listeners = [];
  int _timerDurationMinutes = AppConstants.defaultTimerDurationMinutes;

  /// 初始化服务
  Future<void> initialize() async {
    // 从设置中加载倒计时时长
    // TODO: 从 SharedPreferences 加载
    _startUpdateTimer();
  }

  /// 设置倒计时时长
  void setTimerDuration(int minutes) {
    _timerDurationMinutes = minutes;
  }

  /// 获取当前倒计时时长
  int getTimerDuration() => _timerDurationMinutes;

  /// 启动计时器
  Future<void> startTimer(String uid, String name) async {
    // 如果已存在，先停止旧的
    if (_activeTimers.containsKey(uid)) {
      await stopTimer(uid);
    }

    // 检查是否超过最大并发数
    if (_activeTimers.length >= AppConstants.maxConcurrentTimers) {
      throw Exception('已达到最大并发计时器数量（${AppConstants.maxConcurrentTimers}）');
    }

    final record = TimerRecord(
      uid: uid,
      name: name,
      startTime: DateTime.now(),
      durationMinutes: _timerDurationMinutes,
      isActive: true,
    );

    _activeTimers[uid] = record;

    // 记录到历史
    await DatabaseService().insertHistoryRecord(
      HistoryRecord(
        id: '${uid}_${DateTime.now().millisecondsSinceEpoch}',
        uid: uid,
        name: name,
        checkInTime: DateTime.now(),
      ),
    );

    _notifyListeners();
  }

  /// 停止计时器
  Future<void> stopTimer(String uid) async {
    final record = _activeTimers.remove(uid);
    if (record != null) {
      record.isActive = false;
      record.endTime = DateTime.now();
      
      // 更新历史记录
      // TODO: 更新对应的历史记录为已完成
    }
    _notifyListeners();
  }

  /// 重置计时器（同一 UID 再次刷卡）
  Future<void> resetTimer(String uid, String name) async {
    await stopTimer(uid);
    await startTimer(uid, name);
  }

  /// 获取所有活跃计时器
  List<TimerRecord> getActiveTimers() {
    return _activeTimers.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 获取指定 UID 的计时器
  TimerRecord? getTimer(String uid) {
    return _activeTimers[uid];
  }

  /// 添加监听器
  void addListener(Function(List<TimerRecord>) listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  void removeListener(Function(List<TimerRecord>) listener) {
    _listeners.remove(listener);
  }

  /// 通知所有监听器
  void _notifyListeners() {
    final timers = getActiveTimers();
    for (final listener in _listeners) {
      listener(timers);
    }
  }

  /// 启动更新定时器
  void _startUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      bool hasTimeout = false;
      
      // 检查是否有超时的计时器
      for (final record in _activeTimers.values) {
        if (record.isTimeout) {
          hasTimeout = true;
          break;
        }
      }

      // 通知监听器更新 UI
      _notifyListeners();

      // 如果有超时，触发报警（由 AlarmService 处理）
      if (hasTimeout) {
        // TODO: 触发报警
      }
    });
  }

  /// 清理资源
  void dispose() {
    _updateTimer?.cancel();
    _listeners.clear();
    _activeTimers.clear();
  }
}

