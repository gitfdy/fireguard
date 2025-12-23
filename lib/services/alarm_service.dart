import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
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

  /// 初始化服务
  Future<void> initialize() async {
    _audioPlayer = AudioPlayer();
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
  Future<void> _performAlarmActions(TimerRecord timer) async {
    // 1. 自动拨号
    await _makeEmergencyCall();

    // 2. 播放警报音
    await _playAlarmSound();

    // 3. 震动
    await _vibrate();
  }

  /// 自动拨打紧急电话
  Future<void> _makeEmergencyCall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phones = prefs.getStringList(AppConstants.keyEmergencyPhones) ?? 
                     [AppConstants.defaultEmergencyPhone];
      
      if (phones.isNotEmpty) {
        final phone = phones.first;
        final uri = Uri.parse('tel:$phone');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } catch (e) {
      // 忽略拨号错误
    }
  }

  /// 播放警报音
  Future<void> _playAlarmSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundEnabled = prefs.getBool(AppConstants.keyAlarmSoundEnabled) ?? true;
      
      if (!soundEnabled || _isPlayingAlarm) return;

      _isPlayingAlarm = true;
      // TODO: 加载并播放警报音文件
      // 这里可以使用系统提示音或自定义音频文件
    } catch (e) {
      // 忽略音频错误
    }
  }

  /// 停止警报音
  Future<void> stopAlarmSound() async {
    try {
      await _audioPlayer?.stop();
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
      
      // 停止报警音和震动
      await stopAlarmSound();
      _vibrationTimer?.cancel();
      
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
    _listeners.clear();
    _activeAlarms.clear();
  }
}

