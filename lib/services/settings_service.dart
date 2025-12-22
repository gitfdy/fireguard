import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// 设置服务
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;

  /// 初始化
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 获取倒计时时长（分钟）
  Future<int> getTimerDuration() async {
    await _ensureInitialized();
    return _prefs!.getInt(AppConstants.keyTimerDuration) ?? 
           AppConstants.defaultTimerDurationMinutes;
  }

  /// 设置倒计时时长（分钟）
  Future<void> setTimerDuration(int minutes) async {
    await _ensureInitialized();
    await _prefs!.setInt(AppConstants.keyTimerDuration, minutes);
  }

  /// 获取紧急联系电话列表
  Future<List<String>> getEmergencyPhones() async {
    await _ensureInitialized();
    return _prefs!.getStringList(AppConstants.keyEmergencyPhones) ?? 
           [AppConstants.defaultEmergencyPhone];
  }

  /// 设置紧急联系电话列表
  Future<void> setEmergencyPhones(List<String> phones) async {
    await _ensureInitialized();
    await _prefs!.setStringList(AppConstants.keyEmergencyPhones, phones);
  }

  /// 获取警报音是否启用
  Future<bool> isAlarmSoundEnabled() async {
    await _ensureInitialized();
    return _prefs!.getBool(AppConstants.keyAlarmSoundEnabled) ?? true;
  }

  /// 设置警报音是否启用
  Future<void> setAlarmSoundEnabled(bool enabled) async {
    await _ensureInitialized();
    await _prefs!.setBool(AppConstants.keyAlarmSoundEnabled, enabled);
  }

  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await initialize();
    }
  }
}

