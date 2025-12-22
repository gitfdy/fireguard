import 'package:flutter/material.dart';
import '../models/timer_record.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// 计时器卡片组件
class TimerCard extends StatelessWidget {
  final TimerRecord timer;
  final VoidCallback? onTap;

  const TimerCard({
    super.key,
    required this.timer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color backgroundColor;

    if (timer.isTimeout) {
      textColor = AppColors.timeoutRed;
      backgroundColor = AppColors.timeoutRed.withOpacity(0.1);
    } else if (timer.isWarning) {
      textColor = AppColors.warningOrange;
      backgroundColor = AppColors.warningOrange.withOpacity(0.1);
    } else {
      textColor = AppColors.textPrimaryDark;
      backgroundColor = Colors.transparent;
    }

    return Card(
      color: backgroundColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
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
    );
  }
}

