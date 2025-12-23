import 'package:flutter/foundation.dart';
import '../models/timer_record.dart';
import '../services/timer_service.dart';

/// 计时器状态管理
class TimerProvider extends ChangeNotifier {
  final TimerService _timerService = TimerService();
  List<TimerRecord> _activeTimers = [];

  TimerProvider() {
    _timerService.addListener(_onTimersUpdated);
    _loadTimers();
  }

  List<TimerRecord> get activeTimers => _activeTimers;

  void _onTimersUpdated(List<TimerRecord> timers) {
    _activeTimers = timers;
    notifyListeners();
  }

  void _loadTimers() {
    _activeTimers = _timerService.getActiveTimers();
    notifyListeners();
  }

  Future<void> startTimer(String uid, String name, {int? durationMinutes}) async {
    await _timerService.startTimer(uid, name, durationMinutes: durationMinutes);
  }

  Future<void> resetTimer(String uid, String name, {int? durationMinutes}) async {
    await _timerService.resetTimer(uid, name, durationMinutes: durationMinutes);
  }

  TimerRecord? getTimer(String uid) {
    return _timerService.getTimer(uid);
  }

  @override
  void dispose() {
    _timerService.removeListener(_onTimersUpdated);
    super.dispose();
  }
}

