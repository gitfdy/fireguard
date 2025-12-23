/// 应用常量
class AppConstants {
  // 默认倒计时时长（分钟）
  static const int defaultTimerDurationMinutes = 20;
  
  // 最小倒计时时长（分钟）
  static const int minTimerDurationMinutes = 10;
  
  // 最大倒计时时长（分钟）
  static const int maxTimerDurationMinutes = 60;
  
  // 警告阈值（秒）- 小于5分钟时显示警告
  static const int warningThresholdSeconds = 300;
  
  // 最大并发计时器数量
  static const int maxConcurrentTimers = 20;
  
  // 默认紧急联系电话
  static const String defaultEmergencyPhone = '119';
  
  // UID 前缀
  static const String uidPrefix = 'F';
  
  // 数据库名称
  static const String databaseName = 'fireguard.db';
  static const int databaseVersion = 2;
  
  // SharedPreferences 键名
  static const String keyTimerDuration = 'timer_duration';
  static const String keyEmergencyPhones = 'emergency_phones';
  static const String keyAlarmSoundEnabled = 'alarm_sound_enabled';
  static const String keyThemeType = 'theme_type';
  static const String keyTaskPassword = 'task_password';
  static const String keyTaskActive = 'task_active';
  
  // NFC 数据格式
  static const String nfcMimeType = 'text/plain';
}

