import 'dart:convert';
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/ndef_record.dart';
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
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            // 使用平台特定的 Ndef 类
            final ndef = NdefAndroid.from(tag);
            if (ndef == null) {
              onError?.call('此标签不支持 NDEF 格式');
              return;
            }

            final ndefMessage = await ndef.getNdefMessage();
            if (ndefMessage == null || ndefMessage.records.isEmpty) {
              onError?.call('标签为空，请先注册');
              return;
            }

            // 读取第一个 Text Record
            final record = ndefMessage.records.first;
            if (record.typeNameFormat != TypeNameFormat.wellKnown) {
              onError?.call('标签格式不正确');
              return;
            }

            // 检查是否是 Text Record (type = "T" = 0x54)
            if (record.type.length != 1 || record.type[0] != 0x54) {
              onError?.call('标签不是 Text Record 格式');
              return;
            }

            // 解析 Text Record 数据
            // Text Record 格式：第一个字节是语言代码长度，然后是语言代码，然后是文本
            String text;
            try {
              final payload = record.payload;
              if (payload.isEmpty) {
                onError?.call('标签数据为空');
                return;
              }
              
              // 读取第一个字节获取语言代码长度
              final languageCodeLength = payload[0];
              
              // 跳过语言代码长度字节(1) + 语言代码本身(N字节)，然后读取文本内容
              final textStartIndex = 1 + languageCodeLength;
              if (textStartIndex >= payload.length) {
                onError?.call('标签数据格式错误：数据长度不足');
                return;
              }
              
              // 提取文本部分并解码
              final textBytes = payload.sublist(textStartIndex);
              text = utf8.decode(textBytes);
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

  /// 创建 Text Record
  NdefRecord _createTextRecord(String text) {
    // Text Record 格式：
    // typeNameFormat: wellKnown
    // type: "T" (0x54)
    // identifier: 空
    // payload: [语言代码长度(1字节)][语言代码][文本内容]
    // 默认使用 "en" 作为语言代码
    
    final languageCode = 'en';
    final languageCodeBytes = utf8.encode(languageCode);
    final textBytes = utf8.encode(text);
    
    final payload = Uint8List(1 + languageCodeBytes.length + textBytes.length);
    payload[0] = languageCodeBytes.length; // 语言代码长度
    payload.setRange(1, 1 + languageCodeBytes.length, languageCodeBytes); // 语言代码
    payload.setRange(1 + languageCodeBytes.length, payload.length, textBytes); // 文本内容
    
    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x54]), // "T"
      identifier: Uint8List(0),
      payload: payload,
    );
  }

  /// 写入 NFC 标签
  Future<bool> writeTag(Firefighter firefighter) async {
    final available = await isAvailable();
    if (!available) {
      throw Exception('NFC 不可用');
    }

    try {
      bool writeSuccess = false;
      String? errorMessage;
      
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = NdefAndroid.from(tag);
            if (ndef == null) {
              throw Exception('此标签不支持 NDEF 格式');
            }

            // 检查是否已有数据
            final existingMessage = await ndef.getNdefMessage();
            if (existingMessage != null && existingMessage.records.isNotEmpty) {
              throw Exception('此卡已注册，请使用空白卡');
            }

            // 创建 NDEF 消息
            final jsonString = firefighter.toNfcJson();
            final record = _createTextRecord(jsonString);
            final ndefMessage = NdefMessage(records: [record]);

            // 写入标签
            await ndef.writeNdefMessage(ndefMessage);
            writeSuccess = true;
            await NfcManager.instance.stopSession();
          } catch (e) {
            errorMessage = e.toString();
            await NfcManager.instance.stopSession();
            throw e;
          }
        },
      );

      // 等待写入完成
      int waitCount = 0;
      while (!writeSuccess && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }

      if (!writeSuccess) {
        throw Exception(errorMessage ?? '写入超时');
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
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = NdefAndroid.from(tag);
            if (ndef == null) {
              isEmpty = false;
              await NfcManager.instance.stopSession();
              return;
            }

            final message = await ndef.getNdefMessage();
            isEmpty = message == null || message.records.isEmpty;
            await NfcManager.instance.stopSession();
          } catch (e) {
            isEmpty = false;
            await NfcManager.instance.stopSession();
          }
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
