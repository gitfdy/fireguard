import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/alarm_record.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// 报警弹窗
class AlarmDialog extends StatefulWidget {
  final AlarmRecord alarm;

  const AlarmDialog({
    super.key,
    required this.alarm,
  });

  @override
  State<AlarmDialog> createState() => _AlarmDialogState();
}

class _AlarmDialogState extends State<AlarmDialog> {
  bool _showConfirmDialog = false;

  @override
  void initState() {
    super.initState();
    // 阻止返回键关闭
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: AppColors.timeoutRed),
    );
  }

  void _showConfirmDialogDialog() {
    setState(() {
      _showConfirmDialog = true;
    });
  }

  void _handleConfirm() {
    // 先关闭确认对话框
    setState(() {
      _showConfirmDialog = false;
    });
    // 然后关闭主报警对话框并返回true
    Navigator.of(context).pop(true);
  }

  void _handleCancel() {
    setState(() {
      _showConfirmDialog = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WillPopScope(
          onWillPop: () async => false, // 阻止返回键关闭
          child: Dialog(
            backgroundColor: AppColors.timeoutRed,
            insetPadding: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: AppColors.timeoutRed,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 120,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        '🚨 超时报警 🚨',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '${widget.alarm.name} 已超时未返回！',
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeTitle,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'UID: ${widget.alarm.uid}',
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeBody,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        '已自动拨打紧急电话',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeBody,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _showConfirmDialogDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.timeoutRed,
                          minimumSize: const Size(double.infinity, 72),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        child: const Text(
                          '✅ 确认已处理',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_showConfirmDialog) _buildConfirmDialog(),
      ],
    );
  }

  Widget _buildConfirmDialog() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: AppColors.warningOrange,
                ),
                const SizedBox(height: 16),
                const Text(
                  '确认已处理报警？',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeTitle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '请确认现场情况已处理，\n此操作将关闭报警。',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _handleCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.timeoutRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('确认'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
