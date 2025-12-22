import '../constants/app_constants.dart';

/// UID 生成器
class UidGenerator {
  /// 生成唯一 UID
  static String generate() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${AppConstants.uidPrefix}$timestamp';
  }
}

