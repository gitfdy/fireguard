import 'dart:async';
import 'package:flutter/material.dart';
import '../models/timer_record.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// 计时器卡片组件
class TimerCard extends StatefulWidget {
  final TimerRecord timer;
  final VoidCallback? onTap;

  const TimerCard({
    super.key,
    required this.timer,
    this.onTap,
  });

  @override
  State<TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<TimerCard> {
  Timer? _blinkTimer;
  bool _isBlinking = false;

  @override
  void initState() {
    super.initState();
    if (widget.timer.isWarning || widget.timer.isTimeout) {
      _startBlinking();
    }
  }

  @override
  void didUpdateWidget(TimerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timer.isWarning || widget.timer.isTimeout) {
      if (!_isBlinking) {
        _startBlinking();
      }
    } else {
      _stopBlinking();
    }
  }

  void _startBlinking() {
    _isBlinking = true;
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _stopBlinking() {
    _isBlinking = false;
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  @override
  void dispose() {
    _stopBlinking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = widget.timer;
    Color textColor;
    Color backgroundColor;
    double opacity = 1.0;

    if (timer.isTimeout) {
      textColor = AppColors.timeoutRed;
      backgroundColor = AppColors.timeoutRed.withOpacity(0.1);
      // 超时时持续闪烁
      opacity = _isBlinking ? (DateTime.now().millisecond % 1000 < 500 ? 1.0 : 0.5) : 1.0;
    } else if (timer.isWarning) {
      textColor = AppColors.warningOrange;
      backgroundColor = AppColors.warningOrange.withOpacity(0.1);
      // 警告时闪烁
      opacity = _isBlinking ? (DateTime.now().millisecond % 1000 < 500 ? 1.0 : 0.6) : 1.0;
    } else {
      textColor = AppColors.textPrimaryDark;
      backgroundColor = Colors.transparent;
      opacity = 1.0;
    }

    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 500),
      child: Card(
        color: backgroundColor,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timer.name,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeName,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'UID: ${timer.uid}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeTimer,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontFamily: 'Roboto Mono',
                  ),
                  child: Text(
                    timer.getFormattedRemainingTime(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

