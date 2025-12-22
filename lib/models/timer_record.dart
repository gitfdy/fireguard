/// 计时记录模型
class TimerRecord {
  final String uid;
  final String name;
  final DateTime startTime;
  final int durationMinutes;
  DateTime? endTime;
  bool isActive;

  TimerRecord({
    required this.uid,
    required this.name,
    required this.startTime,
    required this.durationMinutes,
    this.endTime,
    this.isActive = true,
  });

  /// 获取剩余秒数
  int getRemainingSeconds() {
    if (!isActive) return 0;
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    final total = durationMinutes * 60;
    final remaining = total - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// 是否已超时
  bool get isTimeout {
    return isActive && getRemainingSeconds() == 0;
  }

  /// 是否即将超时（小于5分钟）
  bool get isWarning {
    if (!isActive) return false;
    final remaining = getRemainingSeconds();
    return remaining > 0 && remaining < 300; // 5分钟 = 300秒
  }

  /// 格式化剩余时间显示
  String getFormattedRemainingTime() {
    final seconds = getRemainingSeconds();
    if (seconds <= 0) return '00:00';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'startTime': startTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'endTime': endTime?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
    };
  }

  factory TimerRecord.fromJson(Map<String, dynamic> json) {
    return TimerRecord(
      uid: json['uid'] as String,
      name: json['name'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      durationMinutes: json['durationMinutes'] as int,
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime'] as String) 
          : null,
      isActive: (json['isActive'] as int) == 1,
    );
  }
}

