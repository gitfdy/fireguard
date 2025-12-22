import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// 紧急电话列表管理页面
class EmergencyPhonesScreen extends StatefulWidget {
  const EmergencyPhonesScreen({super.key});

  @override
  State<EmergencyPhonesScreen> createState() => _EmergencyPhonesScreenState();
}

class _EmergencyPhonesScreenState extends State<EmergencyPhonesScreen> {
  final SettingsService _settingsService = SettingsService();
  final TextEditingController _phoneController = TextEditingController();
  List<String> _phones = [];

  @override
  void initState() {
    super.initState();
    _loadPhones();
  }

  Future<void> _loadPhones() async {
    final phones = await _settingsService.getEmergencyPhones();
    setState(() {
      _phones = phones;
    });
  }

  Future<void> _addPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackBar('请输入电话号码', isError: true);
      return;
    }

    // 简单验证电话号码格式
    if (!RegExp(r'^[\d\+\-\(\)\s]+$').hasMatch(phone)) {
      _showSnackBar('电话号码格式不正确', isError: true);
      return;
    }

    if (_phones.contains(phone)) {
      _showSnackBar('该电话号码已存在', isError: true);
      return;
    }

    _phones.add(phone);
    await _settingsService.setEmergencyPhones(_phones);
    _phoneController.clear();
    
    setState(() {});
    _showSnackBar('已添加', isError: false);
  }

  Future<void> _removePhone(String phone) async {
    _phones.remove(phone);
    await _settingsService.setEmergencyPhones(_phones);
    setState(() {});
    _showSnackBar('已删除', isError: false);
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.timeoutRed : AppColors.successGreen,
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('紧急电话管理'),
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
                    '添加紧急电话',
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
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: AppTheme.fontSizeName),
                          decoration: InputDecoration(
                            hintText: '请输入电话号码',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addPhone,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(80, 56),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('添加'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '报警时将按顺序拨打，直到接通',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_phones.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    '暂无紧急电话\n请添加至少一个紧急电话',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppColors.textSecondaryDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '紧急电话列表（${_phones.length}）',
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeBody,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _phones.length,
                    itemBuilder: (context, index) {
                      final phone = _phones[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryRed,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          phone,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeName,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.timeoutRed),
                          onPressed: () => _removePhone(phone),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

