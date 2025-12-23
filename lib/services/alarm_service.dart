import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../models/alarm_record.dart';
import '../models/timer_record.dart';
import 'database_service.dart';
import 'timer_service.dart';
import '../constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 报警服务
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final Map<String, AlarmRecord> _activeAlarms = {};
  final List<Function(List<AlarmRecord>)> _listeners = [];
  AudioPlayer? _audioPlayer;
  bool _isPlayingAlarm = false;
  Timer? _vibrationTimer;
  Timer? _callDelayTimer; // 延迟拨号的定时器
  static const int callDelaySeconds = 10; // 延迟10秒后拨打电话
  static const int callCooldownSeconds = 30; // 拨打电话的冷却期（30秒内不重复拨打）
  DateTime? _lastCallTime; // 上次拨打电话的时间

  /// 初始化服务
  Future<void> initialize() async {
    _audioPlayer = AudioPlayer();
    // 设置音频播放模式为警报模式，以便在静音模式下也能播放
    try {
      // 对于Android，设置音频流类型为ALARM
      // 注意：audioplayers包可能不直接支持，需要通过平台通道实现
      // 这里先初始化AudioPlayer，实际的音频流设置会在播放时通过平台通道实现
    } catch (e) {
      // 忽略初始化错误
    }
  }

  /// 检查并触发超时报警
  Future<void> checkAndTriggerAlarms() async {
    final timers = TimerService().getActiveTimers();
    
    for (final timer in timers) {
      // 只有当计时器超时且该UID没有活跃报警时才触发
      // 注意：即使报警被处理了，只要计时器还在运行且超时，就不应该再次触发
      // 除非用户重新刷卡重置了计时器
      if (timer.isTimeout && !_activeAlarms.containsKey(timer.uid)) {
        await triggerAlarm(timer);
      }
    }
  }

  /// 触发报警
  Future<void> triggerAlarm(TimerRecord timer) async {
    // 创建报警记录
    final alarmRecord = AlarmRecord(
      id: '${timer.uid}_${DateTime.now().millisecondsSinceEpoch}',
      uid: timer.uid,
      name: timer.name,
      alarmTime: DateTime.now(),
      isHandled: false,
    );

    _activeAlarms[timer.uid] = alarmRecord;
    
    // 保存到数据库
    await DatabaseService().insertAlarmRecord(alarmRecord);

    // 触发报警动作
    await _performAlarmActions(timer);

    _notifyListeners();
  }

  /// 执行报警动作
  /// 由于Android系统在拨打电话时会占用音频通道，导致报警音无法播放
  /// 因此采用延迟拨号策略：
  /// 1. 立即播放报警音和震动（提供即时反馈）
  /// 2. 显示10秒倒计时
  /// 3. 如果10秒内无人处理，再拨打紧急电话
  /// 
  /// 对于多个报警同时触发的情况：
  /// - 报警音和震动：每个报警都会触发（但播放逻辑会去重）
  /// - 拨打电话：在30秒冷却期内只拨打一次，避免重复拨打
  Future<void> _performAlarmActions(TimerRecord timer) async {
    // 1. 立即播放报警音和震动（不等待）
    // 注意：如果已经在播放报警音，不会重复播放
    _playAlarmSound();
    _vibrate();
    
    // 2. 延迟10秒后拨打紧急电话（如果报警未被处理且未在冷却期内）
    _scheduleDelayedEmergencyCall(timer.uid);
  }

  /// 安排延迟拨打紧急电话
  /// 如果10秒内报警未被处理，则自动拨打紧急电话
  /// 对于多个报警同时触发的情况，只拨打一次电话（在冷却期内）
  void _scheduleDelayedEmergencyCall(String uid) {
    // 如果已经有定时器在运行，不重复创建
    // 这样可以确保多个报警同时触发时，只使用一个倒计时
    if (_callDelayTimer != null && _callDelayTimer!.isActive) {
      return;
    }
    
    // 设置10秒倒计时
    int remainingSeconds = callDelaySeconds;
    
    _callDelayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingSeconds--;
      
      // 检查是否还有活跃报警
      // 如果所有报警都被处理了，取消拨号
      if (_activeAlarms.isEmpty) {
        timer.cancel();
        _callDelayTimer = null;
        return;
      }
      
      // 倒计时结束，拨打紧急电话（如果不在冷却期内）
      if (remainingSeconds <= 0) {
        timer.cancel();
        _callDelayTimer = null;
        _makeEmergencyCall();
      }
    });
  }

  /// 自动拨打紧急电话
  /// 为了避免多个报警同时触发时重复拨打，设置了30秒冷却期
  /// 在冷却期内，即使有新的报警触发，也不会重复拨打
  Future<void> _makeEmergencyCall() async {
    try {
      // 检查是否在冷却期内
      if (_lastCallTime != null) {
        final timeSinceLastCall = DateTime.now().difference(_lastCallTime!);
        if (timeSinceLastCall.inSeconds < callCooldownSeconds) {
          // 在冷却期内，不重复拨打
          return;
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      final phones = prefs.getStringList(AppConstants.keyEmergencyPhones) ?? 
                     [AppConstants.defaultEmergencyPhone];
      
      if (phones.isNotEmpty) {
        final phone = phones.first;
        final uri = Uri.parse('tel:$phone');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          // 记录拨打时间
          _lastCallTime = DateTime.now();
        }
      }
    } catch (e) {
      // 忽略拨号错误
    }
  }

  /// 检查是否已经拨打过电话（用于UI显示）
  bool hasCalledEmergency() {
    if (_lastCallTime == null) return false;
    final timeSinceLastCall = DateTime.now().difference(_lastCallTime!);
    return timeSinceLastCall.inSeconds < callCooldownSeconds;
  }

  /// 播放警报音（支持静音模式下播放）
  Future<void> _playAlarmSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundEnabled = prefs.getBool(AppConstants.keyAlarmSoundEnabled) ?? true;
      
      if (!soundEnabled || _isPlayingAlarm) return;

      _isPlayingAlarm = true;
      
      // 通过平台通道播放系统报警音（最可靠的方法）
      // 这会使用STREAM_ALARM音频流，即使在静音模式下也能播放
      // STREAM_ALARM是专门为报警设计的音频流，会绕过静音模式
      try {
        const platform = MethodChannel('com.fireguard.alarm/audio');
        // 先设置音频流类型为ALARM
        await platform.invokeMethod('setAlarmStream');
        // 然后播放系统报警音（循环播放）
        await platform.invokeMethod('playSystemAlarm');
      } catch (e) {
        // 如果平台通道失败，记录错误但不影响其他报警功能
        // 用户仍然可以通过震动和通知感知到报警
      }
    } catch (e) {
      // 忽略音频错误，但确保通知能显示
      _isPlayingAlarm = false;
    }
  }


  /// 停止警报音
  Future<void> stopAlarmSound() async {
    try {
      // 停止AudioPlayer（如果正在播放）
      await _audioPlayer?.stop();
      
      // 停止平台通道播放的报警音
      try {
        const platform = MethodChannel('com.fireguard.alarm/audio');
        await platform.invokeMethod('stopAlarmSound');
      } catch (e) {
        // 忽略平台通道错误
      }
      
      _isPlayingAlarm = false;
    } catch (e) {
      // 忽略错误
    }
  }

  /// 震动
  Future<void> _vibrate() async {
    try {
      if (await Vibration.hasVibrator()) {
        // 震动 3 秒
        await Vibration.vibrate(duration: 3000);
      }
    } catch (e) {
      // 忽略震动错误
    }
  }

  /// 确认处理报警
  Future<void> handleAlarm(String uid) async {
    final alarm = _activeAlarms.remove(uid);
    if (alarm != null) {
      await DatabaseService().updateAlarmRecordHandled(
        alarm.id,
        DateTime.now(),
      );
      
      // 如果所有报警都已处理，停止报警音和震动
      if (_activeAlarms.isEmpty) {
        await stopAlarmSound();
        _vibrationTimer?.cancel();
        
        // 取消延迟拨号定时器
        _callDelayTimer?.cancel();
        _callDelayTimer = null;
      }
      
      // 重置计时器并重新开始计时
      // 这样用户可以继续监控该人员，计时器从0开始重新计时
      final timerService = TimerService();
      final timers = timerService.getActiveTimers();
      final timer = timers.firstWhere(
        (t) => t.uid == uid,
        orElse: () => timers.isNotEmpty ? timers.first : throw Exception('Timer not found'),
      );
      
      if (timer.uid == uid) {
        // 重置计时器：停止旧的，启动新的
        await timerService.resetTimer(uid, alarm.name);
      }
      
      _notifyListeners();
    }
  }

  /// 获取所有活跃报警
  List<AlarmRecord> getActiveAlarms() {
    return _activeAlarms.values.toList();
  }

  /// 清除所有报警
  Future<void> clearAllAlarms() async {
    // 将所有活跃报警标记为已处理
    final alarms = _activeAlarms.values.toList();
    for (final alarm in alarms) {
      await DatabaseService().updateAlarmRecordHandled(
        alarm.id,
        DateTime.now(),
      );
    }
    
    // 清除活跃报警列表
    _activeAlarms.clear();
    
    // 停止报警音和震动
    await stopAlarmSound();
    _vibrationTimer?.cancel();
    
    // 取消延迟拨号定时器
    _callDelayTimer?.cancel();
    _callDelayTimer = null;
    
    _notifyListeners();
  }

  /// 添加监听器
  void addListener(Function(List<AlarmRecord>) listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  void removeListener(Function(List<AlarmRecord>) listener) {
    _listeners.remove(listener);
  }

  /// 通知所有监听器
  void _notifyListeners() {
    final alarms = getActiveAlarms();
    for (final listener in _listeners) {
      listener(alarms);
    }
  }

  /// 清理资源
  void dispose() {
    _audioPlayer?.dispose();
    _vibrationTimer?.cancel();
    _callDelayTimer?.cancel();
    _listeners.clear();
    _activeAlarms.clear();
  }

  /// 获取延迟拨号的剩余秒数（用于UI显示倒计时）
  int? getCallDelayRemainingSeconds(String uid) {
    // 如果报警已被处理，返回null
    if (!_activeAlarms.containsKey(uid)) {
      return null;
    }
    // 这里可以返回剩余秒数，但需要更复杂的实现来跟踪每个报警的倒计时
    // 为了简化，暂时返回固定值，UI可以通过计算报警时间来判断
    return null; // 暂时返回null，UI可以通过报警时间计算
  }
}

