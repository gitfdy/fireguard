import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/firefighter.dart';
import '../models/alarm_record.dart';
import '../models/history_record.dart';
import '../models/timer_record.dart';
import '../constants/app_constants.dart';

/// 数据库服务
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 消防员表
    await db.execute('''
      CREATE TABLE firefighters (
        uid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // 报警记录表
    await db.execute('''
      CREATE TABLE alarm_records (
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        name TEXT NOT NULL,
        alarmTime TEXT NOT NULL,
        handledTime TEXT,
        isHandled INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 历史记录表
    await db.execute('''
      CREATE TABLE history_records (
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        name TEXT NOT NULL,
        checkInTime TEXT NOT NULL,
        checkOutTime TEXT,
        completed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 活跃计时器表（用于设备重启后恢复）
    await db.execute('''
      CREATE TABLE active_timers (
        uid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        startTime TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        historyRecordId TEXT,
        lastUpdateTime TEXT NOT NULL
      )
    ''');

    // 创建索引
    await db.execute('CREATE INDEX idx_alarm_time ON alarm_records(alarmTime)');
    await db.execute(
      'CREATE INDEX idx_history_time ON history_records(checkInTime)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 添加活跃计时器表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS active_timers (
          uid TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          startTime TEXT NOT NULL,
          durationMinutes INTEGER NOT NULL,
          historyRecordId TEXT,
          lastUpdateTime TEXT NOT NULL
        )
      ''');
    }
  }

  // ========== 消防员管理 ==========

  Future<void> insertFirefighter(Firefighter firefighter) async {
    final db = await database;
    await db.insert(
      'firefighters',
      firefighter.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Firefighter?> getFirefighterByUid(String uid) async {
    final db = await database;
    final maps = await db.query(
      'firefighters',
      where: 'uid = ?',
      whereArgs: [uid],
    );
    if (maps.isEmpty) return null;
    return Firefighter.fromJson(maps.first);
  }

  Future<List<Firefighter>> getAllFirefighters() async {
    final db = await database;
    final maps = await db.query('firefighters', orderBy: 'createdAt DESC');
    return maps.map((map) => Firefighter.fromJson(map)).toList();
  }

  // ========== 报警记录管理 ==========

  Future<void> insertAlarmRecord(AlarmRecord record) async {
    final db = await database;
    await db.insert(
      'alarm_records',
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateAlarmRecordHandled(String id, DateTime handledTime) async {
    final db = await database;
    await db.update(
      'alarm_records',
      {'isHandled': 1, 'handledTime': handledTime.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<AlarmRecord>> getAlarmRecords({
    int limit = 100,
    DateTime? startDate,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (startDate != null) {
      where = 'alarmTime >= ?';
      whereArgs = [startDate.toIso8601String()];
    }

    final maps = await db.query(
      'alarm_records',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'alarmTime DESC',
      limit: limit,
    );
    return maps.map((map) => AlarmRecord.fromJson(map)).toList();
  }

  // ========== 历史记录管理 ==========

  Future<void> insertHistoryRecord(HistoryRecord record) async {
    final db = await database;
    await db.insert(
      'history_records',
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateHistoryRecordCheckOut(
    String id,
    DateTime checkOutTime,
  ) async {
    final db = await database;
    await db.update(
      'history_records',
      {'completed': 1, 'checkOutTime': checkOutTime.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<HistoryRecord>> getHistoryRecords({
    int limit = 100,
    DateTime? startDate,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (startDate != null) {
      where = 'checkInTime >= ?';
      whereArgs = [startDate.toIso8601String()];
    }

    final maps = await db.query(
      'history_records',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'checkInTime DESC',
      limit: limit,
    );
    return maps.map((map) => HistoryRecord.fromJson(map)).toList();
  }

  // ========== 活跃计时器管理（用于状态恢复） ==========

  Future<void> saveActiveTimer(TimerRecord timer) async {
    final db = await database;
    await db.insert('active_timers', {
      'uid': timer.uid,
      'name': timer.name,
      'startTime': timer.startTime.toIso8601String(),
      'durationMinutes': timer.durationMinutes,
      'historyRecordId': timer.historyRecordId ?? '',
      'lastUpdateTime': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeActiveTimer(String uid) async {
    final db = await database;
    await db.delete('active_timers', where: 'uid = ?', whereArgs: [uid]);
  }

  Future<List<Map<String, dynamic>>> getActiveTimers() async {
    final db = await database;
    return await db.query('active_timers');
  }

  Future<void> clearActiveTimers() async {
    final db = await database;
    await db.delete('active_timers');
  }

  // ========== 导出日志 ==========

  Future<String> exportLogsAsText() async {
    final alarms = await getAlarmRecords(limit: 1000);
    final histories = await getHistoryRecords(limit: 1000);

    final buffer = StringBuffer();
    buffer.writeln('=== FireGuard 系统日志 ===');
    buffer.writeln('导出时间: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');

    buffer.writeln('=== 报警记录 ===');
    for (final alarm in alarms) {
      buffer.writeln(
        '${alarm.alarmTime.toIso8601String()} | '
        '${alarm.name} (${alarm.uid}) | '
        '已处理: ${alarm.isHandled ? "是" : "否"}',
      );
    }
    buffer.writeln('');

    buffer.writeln('=== 出警历史 ===');
    for (final history in histories) {
      buffer.writeln(
        '${history.checkInTime.toIso8601String()} | '
        '${history.name} (${history.uid}) | '
        '${history.completed ? "已完成" : "进行中"}',
      );
    }

    return buffer.toString();
  }
}
