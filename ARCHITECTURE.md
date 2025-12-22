# FireGuard 代码架构文档

## 项目概述

FireGuard 是一个基于 Flutter 开发的消防员出警安全计时系统，通过 NFC 刷卡触发倒计时，超时自动报警。

## 技术栈

- **框架**: Flutter 3.10.4+
- **状态管理**: Provider
- **数据库**: SQLite (sqflite)
- **NFC**: nfc_manager
- **本地存储**: SharedPreferences
- **目标平台**: Android 8.0+

## 目录结构

```
lib/
├── main.dart                 # 应用入口，初始化服务
├── constants/               # 常量定义
│   ├── app_constants.dart  # 应用常量（时长、限制等）
│   ├── app_colors.dart     # 颜色定义
│   └── app_theme.dart      # 主题配置（暗色模式）
├── models/                 # 数据模型
│   ├── firefighter.dart    # 消防员模型
│   ├── timer_record.dart   # 计时记录模型
│   ├── alarm_record.dart   # 报警记录模型
│   └── history_record.dart # 历史记录模型
├── services/              # 核心服务层
│   ├── database_service.dart    # 数据库服务（SQLite）
│   ├── nfc_service.dart         # NFC 读写服务
│   ├── timer_service.dart        # 计时器服务
│   ├── alarm_service.dart       # 报警服务
│   └── settings_service.dart    # 设置服务（SharedPreferences）
├── providers/             # 状态管理
│   ├── timer_provider.dart  # 计时器状态
│   └── alarm_provider.dart  # 报警状态
├── screens/              # 页面
│   ├── home_screen.dart      # 主监控屏
│   ├── register_screen.dart  # 注册新消防员
│   ├── settings_screen.dart  # 设置页面
│   └── history_screen.dart   # 历史记录页面
├── widgets/              # 可复用组件
│   ├── timer_card.dart       # 计时器卡片
│   └── alarm_dialog.dart     # 报警弹窗
└── utils/                # 工具类
    └── uid_generator.dart    # UID 生成器
```

## 架构设计

### 1. 分层架构

```
┌─────────────────────────────────────┐
│         UI Layer (Screens)          │
│  HomeScreen, RegisterScreen, etc.   │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      State Layer (Providers)         │
│  TimerProvider, AlarmProvider       │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      Service Layer (Services)        │
│  NFC, Timer, Alarm, Database, etc.   │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      Data Layer (Models)             │
│  Firefighter, TimerRecord, etc.      │
└─────────────────────────────────────┘
```

### 2. 核心服务说明

#### DatabaseService (单例)
- 负责所有数据库操作
- 使用 SQLite 存储消防员信息、报警记录、历史记录
- 提供日志导出功能

#### NfcService (单例)
- NFC 标签读写
- 自动监听 NFC 标签
- 解析 NDEF Text Record 格式的 JSON 数据
- 写入消防员信息到 NFC 卡

#### TimerService (单例)
- 管理多个并发计时器（最多20个）
- 每秒更新计时器状态
- 检测超时并触发报警
- 支持重置计时器

#### AlarmService (单例)
- 处理超时报警
- 自动拨打紧急电话
- 播放警报音和震动
- 记录报警历史

#### SettingsService (单例)
- 管理应用设置（倒计时时长、紧急电话等）
- 使用 SharedPreferences 持久化

### 3. 数据流

#### 刷卡流程
```
NFC 标签 → NfcService.readTag() 
         → Firefighter.fromNfcJson() 
         → TimerService.startTimer() 
         → TimerProvider 更新状态 
         → UI 刷新显示
```

#### 报警流程
```
TimerService 检测超时 
         → AlarmService.triggerAlarm() 
         → 自动拨号 + 播放警报 + 震动 
         → AlarmProvider 更新状态 
         → AlarmDialog 显示
```

### 4. 状态管理

使用 Provider 进行状态管理：
- **TimerProvider**: 管理活跃计时器列表，监听 TimerService 更新
- **AlarmProvider**: 管理活跃报警列表，监听 AlarmService 更新

### 5. 数据模型

- **Firefighter**: 消防员基本信息（UID、姓名、创建时间）
- **TimerRecord**: 计时记录（开始时间、剩余时间、状态）
- **AlarmRecord**: 报警记录（报警时间、处理状态）
- **HistoryRecord**: 历史记录（出警时间、返回时间）

## 关键特性实现

### NFC 读写
- 使用 `nfc_manager` 包
- 支持 NDEF Text Record 格式
- JSON 格式：`{"uid":"F1001","name":"张三"}`

### 前台服务保活
- 使用 `flutter_foreground_task`（待实现）
- 确保应用在后台持续运行

### 权限管理
- NFC 权限
- 电话权限（自动拨号）
- 震动权限
- 前台服务权限

### 主题设计
- 强制暗色模式（根据用户偏好）
- 消防红色主题（#C62828）
- 大字体设计（≥18sp）
- 高对比度配色

## 待完善功能

1. **前台服务**: 实现前台服务保活机制
2. **日志导出**: 完善文件分享功能
3. **音频警报**: 添加自定义警报音文件
4. **系统自检**: 实现系统状态检测页面
5. **紧急电话列表**: 支持多个紧急电话的管理

## 开发注意事项

1. **NFC 测试**: 需要真实 Android 设备和 NFC 标签
2. **权限处理**: 首次运行时需要用户授权
3. **后台保活**: Android 系统可能限制后台运行，需要前台服务
4. **数据持久化**: 所有数据存储在本地，无网络依赖

## 部署要求

- Android 8.0+ 设备
- 支持 NFC 写入的设备
- NTAG213/215/216 等 NDEF 卡
- 建议使用平板设备（7-10英寸）

