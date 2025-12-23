import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timer_provider.dart';
import '../providers/alarm_provider.dart';
import '../widgets/timer_card.dart';
import '../widgets/alarm_dialog.dart';
import '../widgets/system_status_card.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../constants/app_themes.dart';
import 'package:vibration/vibration.dart';
import '../services/nfc_service.dart';
import '../services/timer_service.dart';
import '../services/alarm_service.dart';
import '../services/foreground_service.dart';
import '../models/firefighter.dart';
import '../models/alarm_record.dart';
import 'settings_screen.dart';
import 'system_check_screen.dart';
import '../utils/uid_generator.dart';

/// 主监控屏
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NfcService _nfcService = NfcService();
  final ForegroundServiceManager _foregroundService = ForegroundServiceManager();
  bool _isNfcAvailable = false;
  bool _isListening = false;
  bool _isServiceRunning = false;
  String _statusMessage = '正在初始化...';

  @override
  void initState() {
    super.initState();
    _checkForegroundService();
    _initializeNfc();
    _setupAlarmListener();
    _setupTimerListener();
  }

  Future<void> _checkForegroundService() async {
    final isRunning = _foregroundService.isRunning;
    setState(() {
      _isServiceRunning = isRunning;
    });
    
    // 如果服务未运行，尝试启动
    if (!isRunning) {
      final started = await _foregroundService.start();
      if (mounted) {
        setState(() {
          _isServiceRunning = started;
        });
      }
    }
  }

  Future<void> _initializeNfc() async {
    final available = await _nfcService.isAvailable();
    setState(() {
      _isNfcAvailable = available;
      if (available) {
        _statusMessage = '请将 NFC 卡贴近设备背部';
        _startNfcListening();
      } else {
        _statusMessage = 'NFC 不可用，请检查设备设置';
      }
    });
  }

  void _startNfcListening() {
    if (_isListening) return;
    
    setState(() {
      _isListening = true;
    });

    _nfcService.startSession(
      onTagDiscovered: (Firefighter firefighter) async {
        // 震动反馈
        try {
          if (await Vibration.hasVibrator()) {
            await Vibration.vibrate(duration: 100);
          }
        } catch (e) {
          // 忽略震动错误
        }

        final timerProvider = Provider.of<TimerProvider>(context, listen: false);
        final existingTimer = timerProvider.getTimer(firefighter.uid);
        
        if (existingTimer != null) {
          // 重置计时器
          await timerProvider.resetTimer(firefighter.uid, firefighter.name);
          _showLargeToast('${firefighter.name} 计时已重置', isError: false);
        } else {
          // 启动新计时器
          await timerProvider.startTimer(firefighter.uid, firefighter.name);
          _showLargeToast('${firefighter.name} 已开始计时', isError: false);
        }
      },
      onError: (String error) async {
        // 错误时震动反馈
        try {
          if (await Vibration.hasVibrator()) {
            await Vibration.vibrate(pattern: [0, 200, 100, 200]);
          }
        } catch (e) {
          // 忽略震动错误
        }
        if (mounted) {
          _showLargeToast('错误: $error', isError: true);
        }
      },
    );
  }

  void _setupAlarmListener() {
    final alarmService = AlarmService();
    alarmService.addListener((alarms) {
      if (alarms.isNotEmpty && mounted) {
        // 显示报警弹窗
        for (final alarm in alarms) {
          _showAlarmDialog(alarm);
        }
      }
    });
  }

  void _setupTimerListener() {
    final timerService = TimerService();
    timerService.addListener((timers) {
      // 检查超时并触发报警
      for (final timer in timers) {
        if (timer.isTimeout) {
          AlarmService().checkAndTriggerAlarms();
        }
      }
      
      // 更新前台服务通知
      _updateForegroundNotification(timers.length);
    });
  }

  void _updateForegroundNotification(int activeCount) {
    if (_isServiceRunning) {
      _foregroundService.updateNotification(
        title: 'FireGuard 运行中',
        text: activeCount > 0 
            ? '监控中: $activeCount 名消防员'
            : '等待 NFC 刷卡',
      );
    }
  }

  void _showAlarmDialog(AlarmRecord alarm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlarmDialog(alarm: alarm),
    ).then((handled) {
      if (handled == true) {
        Provider.of<AlarmProvider>(context, listen: false)
            .handleAlarm(alarm.uid);
      }
    });
  }

  void _showLargeToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isError ? AppColors.timeoutRed : AppColors.successGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    );
  }

  @override
  void dispose() {
    _nfcService.stopSession();
    // 注意：不在这里停止前台服务，因为需要保持运行
    super.dispose();
  }

  /// 构建紧凑型状态卡片（系统正常时）
  Widget _buildCompactStatusCard(int activeTimerCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.runningGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: AppColors.runningGreen,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '系统运行正常',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.runningGreen,
            ),
          ),
          const Spacer(),
          Text(
            '监控 $activeTimerCount 人',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department,
              color: AppColors.primaryRed,
              size: 32,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Row(
                children: [
                  // 前台服务状态
                  Icon(
                    _isServiceRunning ? Icons.check_circle : Icons.error_outline,
                    color: _isServiceRunning 
                        ? AppColors.runningGreen 
                        : AppColors.warningOrange,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  // NFC 状态
                  Icon(
                    _isNfcAvailable ? Icons.nfc : Icons.nfc_outlined,
                    color: _isNfcAvailable 
                        ? AppColors.runningGreen 
                        : AppColors.textSecondaryDark,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isServiceRunning && _isNfcAvailable ? '运行中' : '未就绪',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<TimerProvider>(
        builder: (context, timerProvider, child) {
          final timers = timerProvider.activeTimers;
          
          // 系统是否就绪
          final isSystemReady = _isServiceRunning && _isNfcAvailable;
          
          return Column(
            children: [
              // 系统状态卡片（仅在系统未就绪时显示，或作为紧凑型显示）
              if (!isSystemReady)
                SystemStatusCard(
                  isServiceRunning: _isServiceRunning,
                  isNfcAvailable: _isNfcAvailable,
                  activeTimerCount: timers.length,
                )
              else if (timers.isEmpty)
                // 系统正常但无计时器时，显示精简状态卡片
                _buildCompactStatusCard(timers.length),
              
              if (timers.isEmpty)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 大号状态图标
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSystemReady
                                  ? AppColors.runningGreen.withOpacity(0.1)
                                  : AppColors.warningOrange.withOpacity(0.1),
                            ),
                            child: Icon(
                              isSystemReady ? Icons.nfc : Icons.error_outline,
                              size: 64,
                              color: isSystemReady
                                  ? AppColors.runningGreen
                                  : AppColors.warningOrange,
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // 主状态文字
                          Text(
                            isSystemReady ? '系统运行正常' : '系统未就绪',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isSystemReady
                                  ? AppColors.runningGreen
                                  : AppColors.warningOrange,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          
                          // 状态描述
                          Text(
                            isSystemReady
                                ? '等待 NFC 刷卡'
                                : _statusMessage,
                            style: const TextStyle(
                              fontSize: AppTheme.fontSizeBody,
                              color: AppColors.textSecondaryDark,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          // 系统未就绪时显示修复按钮
                          if (!isSystemReady) ...[
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SystemCheckScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.build),
                              label: const Text('前往修复'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.warningOrange,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(200, 56),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ],
                          
                          // 系统正常时显示操作提示
                          if (isSystemReady) ...[
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.darkBackground.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.textSecondaryDark.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.lightbulb_outline,
                                        size: 20,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        '操作提示',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    '• 刷卡后自动开始计时\n• 返回时再次刷卡重置计时器\n• 超时未归将自动报警',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textSecondaryDark,
                                      height: 1.6,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: timers.length,
                    itemBuilder: (context, index) {
                      return TimerCard(timer: timers[index]);
                    },
                  ),
                ),
              
              // 底部提示条（仅在有计时器时显示操作提示）
              if (timers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.darkBackground,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.nfc,
                        size: 18,
                        color: AppColors.textSecondaryDark,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '请将 NFC 卡贴近设备背部',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: _buildTestMenuButton(),
    );
  }

  /// 构建测试菜单按钮
  Widget _buildTestMenuButton() {
    return FloatingActionButton(
      onPressed: () {
        _showTestMenu(context);
      },
      backgroundColor: AppColors.primaryRed,
      child: const Icon(Icons.bug_report, color: Colors.white),
      tooltip: '测试功能',
    );
  }

  /// 显示测试菜单
  void _showTestMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.textSecondaryDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.nfc,
                color: AppColors.runningGreen,
                size: 28,
              ),
              title: const Text(
                '模拟 NFC 刷卡',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              subtitle: const Text(
                '模拟已刷 NFC 卡片后出警状态',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _simulateNfcCard();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.person_add,
                color: AppColors.primaryRed,
                size: 28,
              ),
              title: const Text(
                '添加出警人员',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              subtitle: const Text(
                '模拟添加新的出警人员并开始计时',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _addTestFirefighter();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// 模拟 NFC 刷卡
  Future<void> _simulateNfcCard() async {
    // 创建一个测试消防员
    final testFirefighter = Firefighter(
      uid: 'TEST001',
      name: '测试消防员',
      createdAt: DateTime.now(),
    );

    // 震动反馈
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 100);
      }
    } catch (e) {
      // 忽略震动错误
    }

    // 模拟 NFC 刷卡逻辑
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    final existingTimer = timerProvider.getTimer(testFirefighter.uid);
    
    if (existingTimer != null) {
      // 重置计时器（测试模式：使用1分钟）
      await timerProvider.resetTimer(testFirefighter.uid, testFirefighter.name, durationMinutes: 1);
      _showLargeToast('${testFirefighter.name} 计时已重置（测试模式：1分钟）', isError: false);
    } else {
      // 启动新计时器（测试模式：使用1分钟）
      await timerProvider.startTimer(testFirefighter.uid, testFirefighter.name, durationMinutes: 1);
      _showLargeToast('${testFirefighter.name} 已开始计时（测试模式：1分钟）', isError: false);
    }
  }

  /// 添加测试出警人员
  Future<void> _addTestFirefighter() async {
    // 生成一个唯一的 UID
    final uid = UidGenerator.generate();
    
    // 创建测试消防员（使用序号命名）
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    final activeCount = timerProvider.activeTimers.length;
    final testFirefighter = Firefighter(
      uid: uid,
      name: '测试人员${activeCount + 1}',
      createdAt: DateTime.now(),
    );

    // 震动反馈
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 100);
      }
    } catch (e) {
      // 忽略震动错误
    }

    // 启动计时器
    try {
      await timerProvider.startTimer(testFirefighter.uid, testFirefighter.name);
      _showLargeToast('${testFirefighter.name} 已开始计时', isError: false);
    } catch (e) {
      _showLargeToast('添加失败: $e', isError: true);
    }
  }
}

