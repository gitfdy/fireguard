import 'dart:convert';

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
    try {
      // 使用 jsonDecode 安全解析 JSON
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      
      return Firefighter(
        uid: json['uid'] as String? ?? '',
        name: json['name'] as String? ?? '',
        createdAt: DateTime.now(),
      );
    } catch (e) {
      // 如果解析失败，尝试使用正则表达式作为后备方案
      final uidMatch = RegExp(r'"uid"\s*:\s*"([^"]+)"').firstMatch(jsonString);
      final nameMatch = RegExp(r'"name"\s*:\s*"([^"]+)"').firstMatch(jsonString);
      
      final uid = uidMatch?.group(1) ?? '';
      final name = nameMatch?.group(1) ?? '';
      
      if (uid.isEmpty || name.isEmpty) {
        throw FormatException('无法解析 NFC 数据: $jsonString', e);
      }
      
      return Firefighter(
        uid: uid,
        name: name,
        createdAt: DateTime.now(),
      );
    }
  }
}
