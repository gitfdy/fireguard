import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// 统计信息页面
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  
  int _todayHistoryCount = 0;
  int _todayAlarmCount = 0;
  int _totalHistoryCount = 0;
  int _totalAlarmCount = 0;
  String _mostActiveFirefighter = '暂无';
  double _averageDuration = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      // 今日数据
      final todayHistories = await _dbService.getHistoryRecords(
        startDate: startOfDay,
        limit: 1000,
      );
      final todayAlarms = await _dbService.getAlarmRecords(
        startDate: startOfDay,
        limit: 1000,
      );
      
      // 全部数据
      final allHistories = await _dbService.getHistoryRecords(limit: 10000);
      final allAlarms = await _dbService.getAlarmRecords(limit: 10000);
      
      // 计算最活跃消防员
      final firefighterMap = <String, int>{};
      for (final history in todayHistories) {
        firefighterMap[history.name] = (firefighterMap[history.name] ?? 0) + 1;
      }
      String mostActive = '暂无';
      int maxCount = 0;
      firefighterMap.forEach((name, count) {
        if (count > maxCount) {
          maxCount = count;
          mostActive = name;
        }
      });
      
      // 计算平均时长
      double totalDuration = 0;
      int completedCount = 0;
      for (final history in todayHistories) {
        if (history.completed && history.checkOutTime != null) {
          final duration = history.checkOutTime!
              .difference(history.checkInTime)
              .inMinutes
              .toDouble();
          totalDuration += duration;
          completedCount++;
        }
      }
      final avgDuration = completedCount > 0 ? totalDuration / completedCount : 0.0;
      
      setState(() {
        _todayHistoryCount = todayHistories.length;
        _todayAlarmCount = todayAlarms.length;
        _totalHistoryCount = allHistories.length;
        _totalAlarmCount = allAlarms.length;
        _mostActiveFirefighter = mostActive;
        _averageDuration = avgDuration;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('统计信息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '今日统计',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeTitle,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildStatRow('今日出警', '$_todayHistoryCount 次'),
                          _buildStatRow('今日报警', '$_todayAlarmCount 次'),
                          _buildStatRow('最活跃消防员', _mostActiveFirefighter),
                          if (_averageDuration > 0)
                            _buildStatRow(
                              '平均出警时长',
                              '${_averageDuration.toStringAsFixed(1)} 分钟',
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '累计统计',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeTitle,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildStatRow('累计出警', '$_totalHistoryCount 次'),
                          _buildStatRow('累计报警', '$_totalAlarmCount 次'),
                          if (_totalHistoryCount > 0)
                            _buildStatRow(
                              '报警率',
                              '${(_totalAlarmCount / _totalHistoryCount * 100).toStringAsFixed(1)}%',
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppColors.textSecondaryDark,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeName,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

