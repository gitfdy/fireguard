import 'dart:async';
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
  bool _isConfirming = false;
  int _confirmProgress = 0;
  Timer? _confirmTimer;

  @override
  void initState() {
    super.initState();
    // 阻止返回键关闭
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: AppColors.timeoutRed),
    );
  }

  @override
  void dispose() {
    _confirmTimer?.cancel();
    super.dispose();
  }

  void _startConfirm() {
    setState(() {
      _isConfirming = true;
      _confirmProgress = 0;
    });

    _confirmTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _confirmProgress += 2; // 2秒 = 2000ms / 50ms * 2% = 40次
        if (_confirmProgress >= 100) {
          timer.cancel();
          _handleConfirm();
        }
      });
    });
  }

  void _cancelConfirm() {
    _confirmTimer?.cancel();
    setState(() {
      _isConfirming = false;
      _confirmProgress = 0;
    });
  }

  void _handleConfirm() {
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
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
                  Text(
                    '🚨 超时报警 🚨',
                    style: const TextStyle(
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
                  Text(
                    '已自动拨打紧急电话',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (_isConfirming)
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: _confirmProgress / 100,
                          backgroundColor: Colors.white30,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 8,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '长按确认中...',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeBody,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  else
                    GestureDetector(
                      onLongPressStart: (_) => _startConfirm(),
                      onLongPressEnd: (_) => _cancelConfirm(),
                      child: ElevatedButton(
                        onPressed: _startConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.timeoutRed,
                          minimumSize: const Size(double.infinity, 64),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          '✅ 确认已处理（长按）',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeTitle,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

