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
    // 恢复未完成的计时器
    await _restoreActiveTimers();
    _startUpdateTimer();
  }

  /// 恢复未完成的计时器（设备重启后）
  Future<void> _restoreActiveTimers() async {
    try {
      final savedTimers = await DatabaseService().getActiveTimers();
      final now = DateTime.now();
      
      for (final timerData in savedTimers) {
        final startTime = DateTime.parse(timerData['startTime'] as String);
        final durationMinutes = timerData['durationMinutes'] as int;
        final elapsed = now.difference(startTime).inSeconds;
        final total = durationMinutes * 60;
        
        // 如果已经超时超过5分钟，不恢复（可能已经处理）
        if (elapsed > total + 300) {
          continue;
        }
        
        final record = TimerRecord(
          uid: timerData['uid'] as String,
          name: timerData['name'] as String,
          startTime: startTime,
          durationMinutes: durationMinutes,
          isActive: true,
          historyRecordId: timerData['historyRecordId'] as String?,
        );
        
        _activeTimers[record.uid] = record;
      }
      
      if (_activeTimers.isNotEmpty) {
        _notifyListeners();
      }
    } catch (e) {
      // 忽略恢复错误，继续运行
    }
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

    // 记录到历史
    final historyId = '${uid}_${DateTime.now().millisecondsSinceEpoch}';
    await DatabaseService().insertHistoryRecord(
      HistoryRecord(
        id: historyId,
        uid: uid,
        name: name,
        checkInTime: DateTime.now(),
      ),
    );

    // 保存历史记录ID到计时器记录
    record.historyRecordId = historyId;
    _activeTimers[uid] = record;

    // 持久化到数据库（用于恢复）
    await DatabaseService().saveActiveTimer(record);

    _notifyListeners();
  }

  /// 停止计时器
  Future<void> stopTimer(String uid) async {
    final record = _activeTimers.remove(uid);
    if (record != null) {
      record.isActive = false;
      record.endTime = DateTime.now();
      
      // 更新历史记录为已完成
      if (record.historyRecordId != null) {
        await DatabaseService().updateHistoryRecordCheckOut(
          record.historyRecordId!,
          record.endTime!,
        );
      }
      
      // 从持久化存储中移除
      await DatabaseService().removeActiveTimer(uid);
    }
    _notifyListeners();
  }

  /// 重置计时器（同一 UID 再次刷卡）
  Future<void> resetTimer(String uid, String name) async {
    await stopTimer(uid);
    await startTimer(uid, name);
  }

  /// 获取所有活跃计时器（按紧急程度排序）
  List<TimerRecord> getActiveTimers() {
    final timers = _activeTimers.values.toList();
    
    // 按紧急程度排序：超时 > 警告(<5分钟) > 注意(<10分钟) > 正常
    timers.sort((a, b) {
      if (a.isTimeout && !b.isTimeout) return -1;
      if (!a.isTimeout && b.isTimeout) return 1;
      
      final aRemaining = a.getRemainingSeconds();
      final bRemaining = b.getRemainingSeconds();
      
      // 都超时或都正常，按剩余时间排序
      return aRemaining.compareTo(bRemaining);
    });
    
    return timers;
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

      // 持久化所有活跃计时器（用于恢复）- 异步执行
      Future.microtask(() async {
        for (final record in _activeTimers.values) {
          await DatabaseService().saveActiveTimer(record);
        }
      });

      // 通知监听器更新 UI
      _notifyListeners();

      // 如果有超时，触发报警（由 AlarmService 处理）
      if (hasTimeout) {
        // 报警由 AlarmService.checkAndTriggerAlarms() 处理
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

