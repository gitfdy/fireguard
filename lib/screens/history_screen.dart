import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/alarm_record.dart';
import '../models/history_record.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// 历史记录页面
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<AlarmRecord> _alarms = [];
  List<HistoryRecord> _histories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final alarms = await _dbService.getAlarmRecords(limit: 100);
      final histories = await _dbService.getHistoryRecords(limit: 100);
      
      setState(() {
        _alarms = alarms;
        _histories = histories;
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('历史记录'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '出警历史'),
              Tab(text: '报警记录'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildHistoryList(),
                  _buildAlarmList(),
                ],
              ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_histories.isEmpty) {
      return const Center(
        child: Text('暂无出警记录'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _histories.length,
      itemBuilder: (context, index) {
        final history = _histories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              history.name,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeName,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UID: ${history.uid}'),
                Text(
                  '出警时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(history.checkInTime)}',
                ),
                if (history.completed && history.checkOutTime != null)
                  Text(
                    '返回时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(history.checkOutTime!)}',
                  ),
              ],
            ),
            trailing: Icon(
              history.completed ? Icons.check_circle : Icons.timer,
              color: history.completed 
                  ? AppColors.successGreen 
                  : AppColors.warningOrange,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlarmList() {
    if (_alarms.isEmpty) {
      return const Center(
        child: Text('暂无报警记录'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alarms.length,
      itemBuilder: (context, index) {
        final alarm = _alarms[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: alarm.isHandled 
              ? null 
              : AppColors.timeoutRed.withOpacity(0.1),
          child: ListTile(
            title: Text(
              alarm.name,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeName,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UID: ${alarm.uid}'),
                Text(
                  '报警时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(alarm.alarmTime)}',
                ),
                if (alarm.isHandled && alarm.handledTime != null)
                  Text(
                    '处理时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(alarm.handledTime!)}',
                  ),
              ],
            ),
            trailing: Icon(
              alarm.isHandled ? Icons.check_circle : Icons.warning,
              color: alarm.isHandled 
                  ? AppColors.successGreen 
                  : AppColors.timeoutRed,
            ),
          ),
        );
      },
    );
  }
}

