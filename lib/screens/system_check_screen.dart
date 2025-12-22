import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/nfc_service.dart';
import '../services/foreground_service.dart';
import '../services/database_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// 系统健康检查页面
class SystemCheckScreen extends StatefulWidget {
  const SystemCheckScreen({super.key});

  @override
  State<SystemCheckScreen> createState() => _SystemCheckScreenState();
}

class _SystemCheckScreenState extends State<SystemCheckScreen> {
  final NfcService _nfcService = NfcService();
  final ForegroundServiceManager _foregroundService = ForegroundServiceManager();
  
  bool _nfcAvailable = false;
  bool _nfcPermissionGranted = false;
  bool _phonePermissionGranted = false;
  bool _notificationPermissionGranted = false;
  bool _foregroundServiceRunning = false;
  bool _databaseOk = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkSystemStatus();
  }

  Future<void> _checkSystemStatus() async {
    setState(() {
      _isChecking = true;
    });

    // 检查 NFC
    _nfcAvailable = await _nfcService.isAvailable();
    
    // 检查权限
    // NFC权限在Android中不需要单独申请，通过系统设置控制
    _nfcPermissionGranted = _nfcAvailable; // NFC可用即表示权限已授予
    _phonePermissionGranted = await Permission.phone.isGranted;
    _notificationPermissionGranted = await Permission.notification.isGranted;
    
    // 检查前台服务
    _foregroundServiceRunning = _foregroundService.isRunning;
    
    // 检查数据库
    try {
      await DatabaseService().database;
      _databaseOk = true;
    } catch (e) {
      _databaseOk = false;
    }

    setState(() {
      _isChecking = false;
    });
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();
    await _checkSystemStatus();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.isGranted ? '权限已授予' : '权限被拒绝',
          ),
          backgroundColor: status.isGranted 
              ? AppColors.successGreen 
              : AppColors.timeoutRed,
        ),
      );
    }
  }

  Future<void> _restartForegroundService() async {
    final success = await _foregroundService.restart();
    await _checkSystemStatus();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '前台服务已重启' : '前台服务启动失败',
          ),
          backgroundColor: success 
              ? AppColors.successGreen 
              : AppColors.timeoutRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统自检'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkSystemStatus,
          ),
        ],
      ),
      body: _isChecking
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '系统状态',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeTitle,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildCheckItem(
                          'NFC 功能',
                          _nfcAvailable ? '可用' : '不可用',
                          _nfcAvailable,
                        ),
                        _buildCheckItem(
                          'NFC 权限',
                          _nfcPermissionGranted ? '已授予' : '请在系统设置中开启',
                          _nfcPermissionGranted,
                        ),
                        _buildCheckItem(
                          '电话权限',
                          _phonePermissionGranted ? '已授予' : '未授予',
                          _phonePermissionGranted,
                          onFix: _phonePermissionGranted 
                              ? null 
                              : () => _requestPermission(Permission.phone),
                        ),
                        _buildCheckItem(
                          '通知权限',
                          _notificationPermissionGranted ? '已授予' : '未授予',
                          _notificationPermissionGranted,
                          onFix: _notificationPermissionGranted 
                              ? null 
                              : () => _requestPermission(Permission.notification),
                        ),
                        _buildCheckItem(
                          '前台服务',
                          _foregroundServiceRunning ? '运行中' : '未运行',
                          _foregroundServiceRunning,
                          onFix: _foregroundServiceRunning 
                              ? null 
                              : _restartForegroundService,
                        ),
                        _buildCheckItem(
                          '数据库',
                          _databaseOk ? '正常' : '异常',
                          _databaseOk,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '操作指引',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeTitle,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildGuideItem(
                          '如果 NFC 不可用',
                          '请检查设备是否支持 NFC，并在系统设置中开启 NFC 功能',
                        ),
                        _buildGuideItem(
                          '如果权限未授予',
                          '点击"修复"按钮授予权限，或前往系统设置手动授予',
                        ),
                        _buildGuideItem(
                          '如果前台服务未运行',
                          '点击"修复"按钮重启服务，确保应用在后台持续运行',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCheckItem(
    String label,
    String status,
    bool isOk, {
    VoidCallback? onFix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.error,
            color: isOk ? AppColors.successGreen : AppColors.timeoutRed,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    color: isOk 
                        ? AppColors.textSecondaryDark 
                        : AppColors.timeoutRed,
                  ),
                ),
              ],
            ),
          ),
          if (onFix != null)
            TextButton(
              onPressed: onFix,
              child: const Text('修复'),
            ),
        ],
      ),
    );
  }

  Widget _buildGuideItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
