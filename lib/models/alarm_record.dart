/// 报警记录模型
class AlarmRecord {
  final String id;
  final String uid;
  final String name;
  final DateTime alarmTime;
  final DateTime? handledTime;
  final bool isHandled;

  AlarmRecord({
    required this.id,
    required this.uid,
    required this.name,
    required this.alarmTime,
    this.handledTime,
    this.isHandled = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'name': name,
      'alarmTime': alarmTime.toIso8601String(),
      'handledTime': handledTime?.toIso8601String(),
      'isHandled': isHandled ? 1 : 0,
    };
  }

  factory AlarmRecord.fromJson(Map<String, dynamic> json) {
    return AlarmRecord(
      id: json['id'] as String,
      uid: json['uid'] as String,
      name: json['name'] as String,
      alarmTime: DateTime.parse(json['alarmTime'] as String),
      handledTime: json['handledTime'] != null 
          ? DateTime.parse(json['handledTime'] as String) 
          : null,
      isHandled: (json['isHandled'] as int) == 1,
    );
  }
}

