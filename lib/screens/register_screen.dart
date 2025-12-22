import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/firefighter.dart';
import '../services/nfc_service.dart';
import '../services/database_service.dart';
import '../utils/uid_generator.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// 注册新消防员页面
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final NfcService _nfcService = NfcService();
  bool _isWriting = false;
  String _statusMessage = '请输入姓名，然后将空白卡贴近设备背部';
  bool _isCardDetected = false;
  bool _isCardEmpty = false;

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
  }

  Future<void> _checkNfcAvailability() async {
    final available = await _nfcService.isAvailable();
    if (!available && mounted) {
      setState(() {
        _statusMessage = 'NFC 不可用，请检查设备设置';
      });
    }
  }

  Future<void> _checkCard() async {
    setState(() {
      _statusMessage = '正在检测卡片...';
      _isCardDetected = false;
      _isCardEmpty = false;
    });

    try {
      final isEmpty = await _nfcService.isTagEmpty();
      setState(() {
        _isCardDetected = true;
        _isCardEmpty = isEmpty;
        _statusMessage = isEmpty 
            ? '检测到空白卡，可以写入' 
            : '此卡已注册，请使用空白卡';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '检测失败: $e';
        _isCardDetected = false;
      });
    }
  }

  Future<void> _writeCard() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('请输入姓名', isError: true);
      return;
    }

    if (!_isCardEmpty) {
      _showSnackBar('请先检测卡片是否为空白', isError: true);
      return;
    }

    setState(() {
      _isWriting = true;
      _statusMessage = '正在写入卡片，请保持卡片贴近设备...';
    });

    try {
      final firefighter = Firefighter(
        uid: UidGenerator.generate(),
        name: name,
        createdAt: DateTime.now(),
      );

      await _nfcService.writeTag(firefighter);
      
      // 保存到数据库
      await DatabaseService().insertFirefighter(firefighter);

      if (mounted) {
        _showSnackBar('✅ $name 卡片注册成功！', isError: false);
        _nameController.clear();
        setState(() {
          _isCardDetected = false;
          _isCardEmpty = false;
          _statusMessage = '注册成功！可以继续注册下一张卡';
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('写入失败: $e', isError: true);
        setState(() {
          _statusMessage = '写入失败，请重试';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isWriting = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.timeoutRed : AppColors.successGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('注册新消防员'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '消防员姓名',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              enabled: !_isWriting,
              style: const TextStyle(fontSize: AppTheme.fontSizeName),
              decoration: InputDecoration(
                hintText: '请输入姓名',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Card(
              color: _isCardDetected
                  ? (_isCardEmpty 
                      ? AppColors.successGreen.withOpacity(0.1)
                      : AppColors.timeoutRed.withOpacity(0.1))
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      _isCardDetected
                          ? (_isCardEmpty 
                              ? Icons.check_circle 
                              : Icons.error)
                          : Icons.nfc,
                      size: 48,
                      color: _isCardDetected
                          ? (_isCardEmpty 
                              ? AppColors.successGreen 
                              : AppColors.timeoutRed)
                          : AppColors.textSecondaryDark,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeBody,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isWriting ? null : _checkCard,
              child: const Text('检测卡片'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: (_isWriting || !_isCardEmpty) ? null : _writeCard,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
              ),
              child: _isWriting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('写入卡片'),
            ),
          ],
        ),
      ),
    );
  }
}

