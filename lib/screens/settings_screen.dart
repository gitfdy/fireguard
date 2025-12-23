import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/timer_service.dart';
import '../services/database_service.dart';
import '../constants/app_constants.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../constants/app_themes.dart';
import '../providers/theme_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/alarm_provider.dart';
import '../widgets/pin_input_dialog.dart';
import 'history_screen.dart';
import 'emergency_phones_screen.dart';
import 'system_check_screen.dart';
import 'statistics_screen.dart';
import 'register_screen.dart';

/// 设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final TextEditingController _durationController = TextEditingController();
  bool _alarmSoundEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final duration = await _settingsService.getTimerDuration();
    final soundEnabled = await _settingsService.isAlarmSoundEnabled();
    
    setState(() {
      _alarmSoundEnabled = soundEnabled;
      _durationController.text = duration.toString();
    });
  }

  Future<void> _saveTimerDuration() async {
    final value = int.tryParse(_durationController.text);
    if (value == null || 
        value < AppConstants.minTimerDurationMinutes || 
        value > AppConstants.maxTimerDurationMinutes) {
      _showSnackBar(
        '请输入 ${AppConstants.minTimerDurationMinutes}-${AppConstants.maxTimerDurationMinutes} 之间的数字',
        isError: true,
      );
      return;
    }

    await _settingsService.setTimerDuration(value);
    TimerService().setTimerDuration(value);
    
    _showSnackBar('已保存', isError: false);
  }

  Future<void> _toggleAlarmSound(bool value) async {
    await _settingsService.setAlarmSoundEnabled(value);
    setState(() {
      _alarmSoundEnabled = value;
    });
  }

  Future<void> _exportLogs() async {
    try {
      // TODO: 使用 share_plus 或 file_picker 导出文件
      await DatabaseService().exportLogsAsText();
      _showSnackBar('日志导出功能开发中', isError: false);
    } catch (e) {
      _showSnackBar('导出失败: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.timeoutRed : AppColors.successGreen,
      ),
    );
  }

  /// 显示主题选择器
  void _showThemeSelector(ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                '选择主题',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...AppThemeType.values.map((themeType) {
              final isSelected = themeProvider.currentTheme == themeType;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? AppColors.primaryRed : null,
                  size: 28,
                ),
                title: Text(
                  AppThemes.getThemeName(themeType),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  AppThemes.getThemeDescription(themeType),
                  style: const TextStyle(fontSize: 14),
                ),
                onTap: () async {
                  await themeProvider.setTheme(themeType);
                  Navigator.pop(context);
                  
                  _showSnackBar(
                    '主题已切换',
                    isError: false,
                  );
                },
              );
            }).toList(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '倒计时时长',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '分钟',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('分钟'),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saveTimerDuration,
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '范围: ${AppConstants.minTimerDurationMinutes}-${AppConstants.maxTimerDurationMinutes} 分钟',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('注册新消防员'),
              subtitle: const Text('为新消防员创建并写入NFC卡片'),
              leading: Icon(
                Icons.person_add,
                color: AppColors.primaryRed,
                size: 28,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegisterScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Card(
                child: ListTile(
                  title: const Text('应用主题'),
                  subtitle: Text(AppThemes.getThemeDescription(themeProvider.currentTheme)),
                  leading: const Icon(
                    Icons.palette,
                    size: 28,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showThemeSelector(themeProvider);
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('紧急电话'),
              subtitle: const Text('管理报警时拨打的紧急电话'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmergencyPhonesScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              title: const Text('警报音'),
              subtitle: const Text('超时报警时播放声音'),
              value: _alarmSoundEnabled,
              onChanged: _toggleAlarmSound,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('系统自检'),
              subtitle: const Text('检查系统状态和权限'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SystemCheckScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('历史记录'),
              subtitle: const Text('查看出警和报警历史'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistoryScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('统计信息'),
              subtitle: const Text('查看出警和报警统计数据'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StatisticsScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('导出日志'),
              subtitle: const Text('导出系统日志为文本文件'),
              trailing: const Icon(Icons.share),
              onTap: _exportLogs,
            ),
          ),
          const SizedBox(height: 24),
          // 任务完成按钮
          Card(
            color: AppColors.successGreen.withOpacity(0.1),
            child: ListTile(
              title: const Text(
                '任务完成',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.successGreen,
                ),
              ),
              subtitle: const Text('清除所有计时器和报警，结束本次任务'),
              leading: Icon(
                Icons.check_circle,
                color: AppColors.successGreen,
                size: 32,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showCompleteTaskDialog,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 显示任务完成确认对话框
  void _showCompleteTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warningOrange,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '确认完成任务？',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          '此操作将：\n'
          '• 清除所有活跃的计时器\n'
          '• 清除所有活跃的报警\n'
          '• 更新所有历史记录为已完成\n\n'
          '此操作不可撤销，请确认是否继续？',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _completeTask();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认完成'),
          ),
        ],
      ),
    );
  }

  /// 完成任务：清除所有计时器和报警
  Future<void> _completeTask() async {
    // 检查是否有任务
    final isTaskActive = await _settingsService.isTaskActive();
    if (!isTaskActive) {
      _showSnackBar('当前没有进行中的任务', isError: false);
      return;
    }

    // 获取保存的密码
    final savedPassword = await _settingsService.getTaskPassword();
    if (savedPassword == null || savedPassword.isEmpty) {
      // 如果没有密码，直接完成任务
      await _performCompleteTask();
      return;
    }

    // 显示密码验证对话框
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => const PinInputDialog(
        title: '验证密码',
        subtitle: '请输入创建任务时的4位数密码',
        isVerification: true,
      ),
    );

    if (pin == null) {
      return; // 用户取消
    }

    // 验证密码
    if (pin != savedPassword) {
      _showSnackBar('密码错误，无法完成任务', isError: true);
      return;
    }

    // 密码正确，执行完成任务
    await _performCompleteTask();
  }

  /// 执行完成任务操作
  Future<void> _performCompleteTask() async {
    try {
      // 显示加载提示
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 清除所有计时器
      final timerProvider = Provider.of<TimerProvider>(context, listen: false);
      await timerProvider.clearAllTimers();

      // 清除所有报警
      final alarmProvider = Provider.of<AlarmProvider>(context, listen: false);
      await alarmProvider.clearAllAlarms();

      // 清除任务状态
      await _settingsService.clearTask();

      // 关闭加载提示
      if (mounted) {
        Navigator.pop(context);
      }

      // 显示成功提示
      if (mounted) {
        _showSnackBar('任务已完成，所有计时器和报警已清除', isError: false);
      }
    } catch (e) {
      // 关闭加载提示
      if (mounted) {
        Navigator.pop(context);
      }

      // 显示错误提示
      if (mounted) {
        _showSnackBar('操作失败: $e', isError: true);
      }
    }
  }
}

