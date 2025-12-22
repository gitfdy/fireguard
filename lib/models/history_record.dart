/// 历史记录模型（出警事件）
class HistoryRecord {
  final String id;
  final String uid;
  final String name;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final bool completed;

  HistoryRecord({
    required this.id,
    required this.uid,
    required this.name,
    required this.checkInTime,
    this.checkOutTime,
    this.completed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'name': name,
      'checkInTime': checkInTime.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
      'completed': completed ? 1 : 0,
    };
  }

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    return HistoryRecord(
      id: json['id'] as String,
      uid: json['uid'] as String,
      name: json['name'] as String,
      checkInTime: DateTime.parse(json['checkInTime'] as String),
      checkOutTime: json['checkOutTime'] != null 
          ? DateTime.parse(json['checkOutTime'] as String) 
          : null,
      completed: (json['completed'] as int) == 1,
    );
  }
}

