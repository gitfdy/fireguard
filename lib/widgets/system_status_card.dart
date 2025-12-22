import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../services/database_service.dart';

/// 系统状态卡片组件
class SystemStatusCard extends StatefulWidget {
  final bool isServiceRunning;
  final bool isNfcAvailable;
  final int activeTimerCount;

  const SystemStatusCard({
    super.key,
    required this.isServiceRunning,
    required this.isNfcAvailable,
    required this.activeTimerCount,
  });

  @override
  State<SystemStatusCard> createState() => _SystemStatusCardState();
}

class _SystemStatusCardState extends State<SystemStatusCard> {
  int _todayHistoryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadTodayHistory();
  }

  Future<void> _loadTodayHistory() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final histories = await DatabaseService().getHistoryRecords(
      startDate: startOfDay,
      limit: 1000,
    );
    setState(() {
      _todayHistoryCount = histories.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHealthy = widget.isServiceRunning && widget.isNfcAvailable;

    return Card(
      color: isHealthy 
          ? AppColors.runningGreen.withOpacity(0.1)
          : AppColors.warningOrange.withOpacity(0.1),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isHealthy ? Icons.check_circle : Icons.error_outline,
                  color: isHealthy 
                      ? AppColors.runningGreen 
                      : AppColors.warningOrange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  isHealthy ? '系统运行正常' : '系统未就绪',
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeTitle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusRow(
              Icons.nfc,
              'NFC',
              widget.isNfcAvailable ? '已就绪' : '不可用',
              widget.isNfcAvailable,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              Icons.notifications_active,
              '前台服务',
              widget.isServiceRunning ? '运行中' : '未运行',
              widget.isServiceRunning,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              Icons.timer,
              '当前监控',
              '${widget.activeTimerCount} 人',
              true,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              Icons.history,
              '今日出警',
              '$_todayHistoryCount 次',
              true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String label, String value, bool isOk) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isOk ? AppColors.textSecondaryDark : AppColors.warningOrange,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: AppTheme.fontSizeBody,
            color: AppColors.textSecondaryDark,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppTheme.fontSizeBody,
            fontWeight: FontWeight.w500,
            color: isOk ? AppColors.textPrimaryDark : AppColors.warningOrange,
          ),
        ),
      ],
    );
  }
}

