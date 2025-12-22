import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import '../models/firefighter.dart';

/// NFC 服务
class NfcService {
  static final NfcService _instance = NfcService._internal();
  factory NfcService() => _instance;
  NfcService._internal();

  bool _isAvailable = false;
  bool _isListening = false;

  /// 检查 NFC 是否可用
  Future<bool> isAvailable() async {
    try {
      _isAvailable = await NfcManager.instance.isAvailable();
      return _isAvailable;
    } catch (e) {
      _isAvailable = false;
      return false;
    }
  }

  /// 开始监听 NFC 标签
  Future<void> startSession({
    required Function(Firefighter) onTagDiscovered,
    Function(String)? onError,
  }) async {
    if (_isListening) {
      return;
    }
    
    final available = await isAvailable();
    if (!available) {
      onError?.call('NFC 不可用，请检查设备是否支持 NFC');
      return;
    }

    _isListening = true;
    
    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              onError?.call('此标签不支持 NDEF 格式');
              return;
            }

            final ndefMessage = await ndef.read();
            if (ndefMessage.records.isEmpty) {
              onError?.call('标签为空，请先注册');
              return;
            }

            // 读取第一个 Text Record
            final record = ndefMessage.records.first;
            if (record.typeNameFormat != NdefTypeNameFormat.nfcWellknown) {
              onError?.call('标签格式不正确');
              return;
            }

            // 解析 JSON 数据 - 对于 Text Record，使用 record.additionalData
            String text;
            try {
              final payload = record.payload;
              if (payload.isEmpty) {
                onError?.call('标签数据为空');
                return;
              }
              // Text Record 格式：第一个字节是语言代码长度，然后是语言代码，然后是文本
              text = utf8.decode(payload.skip(1).toList()); // 跳过语言代码长度字节
            } catch (e) {
              onError?.call('解析标签数据失败: $e');
              return;
            }
            
            final firefighter = Firefighter.fromNfcJson(text);
            onTagDiscovered(firefighter);
          } catch (e) {
            onError?.call('读取标签失败: $e');
          }
        },
        onError: (error) async {
          onError?.call('NFC 读取错误: $error');
        },
      );
      return;
    } catch (e) {
      _isListening = false;
      onError?.call('启动 NFC 会话失败: $e');
      return;
    }
  }

  /// 停止监听
  Future<void> stopSession() async {
    if (!_isListening) {
      return;
    }
    try {
      await NfcManager.instance.stopSession();
      _isListening = false;
    } catch (e) {
      // 忽略错误
    }
  }

  /// 写入 NFC 标签
  Future<bool> writeTag(Firefighter firefighter) async {
    final available = await isAvailable();
    if (!available) {
      throw Exception('NFC 不可用');
    }

    try {
      bool writeSuccess = false;
      
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              throw Exception('此标签不支持 NDEF 格式');
            }

            // 检查是否已有数据
            final existingMessage = await ndef.read();
            if (existingMessage.records.isNotEmpty) {
              throw Exception('此卡已注册，请使用空白卡');
            }

            // 创建 NDEF 消息
            final jsonString = firefighter.toNfcJson();

            // 创建 Text Record
            final record = NdefRecord.createText(jsonString);

            final ndefMessage = NdefMessage([record]);

            // 写入标签
            await ndef.write(ndefMessage);
            writeSuccess = true;
            await NfcManager.instance.stopSession();
          } catch (e) {
            await NfcManager.instance.stopSession();
            throw e;
          }
        },
        onError: (error) {
          throw Exception('写入失败: $error');
        },
      );

      // 等待写入完成
      int waitCount = 0;
      while (!writeSuccess && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }

      if (!writeSuccess) {
        throw Exception('写入超时');
      }

      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// 检查标签是否为空
  Future<bool> isTagEmpty() async {
    final available = await isAvailable();
    if (!available) return false;

    try {
      bool? isEmpty;
      
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              isEmpty = false;
              await NfcManager.instance.stopSession();
              return;
            }

            final message = await ndef.read();
            isEmpty = message.records.isEmpty;
            await NfcManager.instance.stopSession();
          } catch (e) {
            isEmpty = false;
            await NfcManager.instance.stopSession();
          }
        },
        onError: (_) async {
          isEmpty = false;
        },
      );

      int waitCount = 0;
      while (isEmpty == null && waitCount < 30) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }

      return isEmpty ?? false;
    } catch (e) {
      return false;
    }
  }
}

