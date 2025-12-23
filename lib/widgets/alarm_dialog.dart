import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/alarm_record.dart';
import '../services/alarm_service.dart';
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

class _AlarmDialogState extends State<AlarmDialog>
    with SingleTickerProviderStateMixin {
  bool _showConfirmDialog = false;
  int _callDelayRemaining = 10; // 延迟拨号的剩余秒数
  Timer? _countdownTimer;
  bool _isCalling = false; // 是否正在拨打电话
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // 初始化脉冲动画控制器
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
    
    // 设置状态栏颜色为红色，图标为白色（适配红色背景）
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.timeoutRed,
        statusBarIconBrightness: Brightness.light, // 白色图标
        statusBarBrightness: Brightness.dark, // Android兼容性
      ),
    );
    // 开始倒计时
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController?.dispose();
    // 恢复默认状态栏样式
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    super.dispose();
  }

  void _startCountdown() {
    // 检查是否已经拨打过电话（可能其他报警已经触发了拨号）
    final alarmService = AlarmService();
    if (alarmService.hasCalledEmergency()) {
      setState(() {
        _isCalling = true;
        _callDelayRemaining = 0;
      });
      return;
    }
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDelayRemaining--;
          
          // 检查是否已经拨打过电话（可能其他报警触发了拨号）
          if (alarmService.hasCalledEmergency()) {
            _isCalling = true;
            _callDelayRemaining = 0;
            timer.cancel();
            return;
          }
          
          if (_callDelayRemaining <= 0) {
            _isCalling = true;
            timer.cancel();
          }
        });
      }
    });
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
              decoration: BoxDecoration(
                color: AppColors.timeoutRed,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.timeoutRed,
                    AppColors.timeoutRed.withOpacity(0.95),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 顶部：警告图标和标题
                      Column(
                        children: [
                          // 警告图标 - 添加脉冲动画
                          _pulseAnimation != null
                              ? AnimatedBuilder(
                                  animation: _pulseAnimation!,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _pulseAnimation!.value,
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.2),
                                        ),
                                        child: const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 100,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 100,
                                    color: Colors.white,
                                  ),
                                ),
                          const SizedBox(height: 24),
                          // 报警标题
                          const Text(
                            '🚨 超时报警 🚨',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),

                      // 中间：人员信息和倒计时（核心区域）
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 人员信息卡片
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    widget.alarm.name,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.0,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '已超时未返回！',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.95),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'UID: ${widget.alarm.uid}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            // 倒计时区域 - 重点优化
                            _buildCountdownSection(),
                          ],
                        ),
                      ),

                      // 底部：确认按钮
                      Column(
                        children: [
                          // 提示文字
                          Text(
                            '请尽快确认处理情况',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 确认按钮 - 增强视觉效果
                          Container(
                            width: double.infinity,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _showConfirmDialogDialog,
                                borderRadius: BorderRadius.circular(16),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.successGreen,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        '确认已处理',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.timeoutRed,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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

  /// 构建倒计时区域 - 重点优化，使其更加醒目
  Widget _buildCountdownSection() {
    final alarmService = AlarmService();
    final hasCalled = alarmService.hasCalledEmergency();

    if (hasCalled || _isCalling) {
      // 已拨打电话状态
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.4),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '已拨打紧急电话',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '（30秒内不会重复拨打）',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else {
      // 倒计时状态 - 重点优化
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.25),
              Colors.white.withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.5),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // 倒计时数字 - 超大号，带脉冲动画
            _pulseAnimation != null
                ? AnimatedBuilder(
                    animation: _pulseAnimation!,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _callDelayRemaining <= 5
                            ? 1.0 + (_pulseAnimation!.value - 1.0) * 0.3
                            : 1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 32,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$_callDelayRemaining',
                                style: TextStyle(
                                  fontSize: 72,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '秒',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 32,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$_callDelayRemaining',
                          style: TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '秒',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
            const SizedBox(height: 20),
            // 描述文字
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.phone_in_talk,
                  size: 24,
                  color: Colors.white.withOpacity(0.95),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '后自动拨打紧急电话',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.95),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '请在倒计时结束前处理报警',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ],
        ),
      );
    }
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
