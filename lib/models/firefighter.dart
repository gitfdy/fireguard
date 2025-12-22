/// 消防员数据模型
class Firefighter {
  final String uid;
  final String name;
  final DateTime createdAt;

  Firefighter({
    required this.uid,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Firefighter.fromJson(Map<String, dynamic> json) {
    return Firefighter(
      uid: json['uid'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// 转换为 NFC 卡写入格式
  String toNfcJson() {
    return '{"uid":"$uid","name":"$name"}';
  }

  /// 从 NFC 卡读取的 JSON 创建
  factory Firefighter.fromNfcJson(String jsonString) {
    // 简单解析，实际应该使用 jsonDecode
    final uidMatch = RegExp(r'"uid":"([^"]+)"').firstMatch(jsonString);
    final nameMatch = RegExp(r'"name":"([^"]+)"').firstMatch(jsonString);
    
    return Firefighter(
      uid: uidMatch?.group(1) ?? '',
      name: nameMatch?.group(1) ?? '',
      createdAt: DateTime.now(),
    );
  }
}

