import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timer_provider.dart';
import '../providers/alarm_provider.dart';
import '../widgets/timer_card.dart';
import '../widgets/alarm_dialog.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../services/nfc_service.dart';
import '../services/timer_service.dart';
import '../services/alarm_service.dart';
import '../services/foreground_service.dart';
import '../models/firefighter.dart';
import '../models/alarm_record.dart';
import 'register_screen.dart';
import 'settings_screen.dart';

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
        final timerProvider = Provider.of<TimerProvider>(context, listen: false);
        final existingTimer = timerProvider.getTimer(firefighter.uid);
        
        if (existingTimer != null) {
          // 重置计时器
          await timerProvider.resetTimer(firefighter.uid, firefighter.name);
          _showSnackBar('${firefighter.name} 计时已重置');
        } else {
          // 启动新计时器
          await timerProvider.startTimer(firefighter.uid, firefighter.name);
          _showSnackBar('${firefighter.name} 已开始计时');
        }
      },
      onError: (String error) {
        _showSnackBar('错误: $error', isError: true);
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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.timeoutRed : AppColors.successGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _nfcService.stopSession();
    // 注意：不在这里停止前台服务，因为需要保持运行
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FireGuard 消防员安全监控'),
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
          
          if (timers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.nfc,
                    size: 80,
                    color: AppColors.textSecondaryDark,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppColors.textSecondaryDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: timers.length,
                  itemBuilder: (context, index) {
                    return TimerCard(timer: timers[index]);
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.darkBackground,
                child: Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    color: AppColors.textSecondaryDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegisterScreen()),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('注册新消防员'),
      ),
    );
  }
}

