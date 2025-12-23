import 'package:flutter/foundation.dart';
import '../models/alarm_record.dart';
import '../services/alarm_service.dart';

/// 报警状态管理
class AlarmProvider extends ChangeNotifier {
  final AlarmService _alarmService = AlarmService();
  List<AlarmRecord> _activeAlarms = [];

  AlarmProvider() {
    _alarmService.addListener(_onAlarmsUpdated);
    _loadAlarms();
  }

  List<AlarmRecord> get activeAlarms => _activeAlarms;

  void _onAlarmsUpdated(List<AlarmRecord> alarms) {
    _activeAlarms = alarms;
    notifyListeners();
  }

  void _loadAlarms() {
    _activeAlarms = _alarmService.getActiveAlarms();
    notifyListeners();
  }

  Future<void> handleAlarm(String uid) async {
    await _alarmService.handleAlarm(uid);
  }

  Future<void> clearAllAlarms() async {
    await _alarmService.clearAllAlarms();
  }

  @override
  void dispose() {
    _alarmService.removeListener(_onAlarmsUpdated);
    super.dispose();
  }
}

