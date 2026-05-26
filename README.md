# 逐句复读播放器 (Sentence Repeater)

一款面向语言学习的跨平台音频复读工具。根据 SRT 字幕文件将音频按句切分，支持逐句复读、变速播放、连续播放控制与进度管理。

## 功能特性

- **逐句播放** — 点击句子卡片即从该句起始播放，播完自动停止或连续下一句
- **单句复读（A-B Loop）** — 双击句子卡片或点击复读按钮，当前句循环播放
- **连续播放开关** — 控制播完一句后是否自动播放下一句（默认开启）
- **变速播放** — 0.5x ~ 2.0x 变速，保持音调不变，设置自动记忆
- **上下句跳转** — 快速切换至前一句或后一句
- **播放进度记忆** — 重新打开文件时询问是否从上次位置继续
- **单个导入** — 选择 MP3 文件，自动匹配同目录同名 SRT 字幕
- **批量导入** — 选择文件夹，自动扫描其中所有 MP3+SRT 配对
- **同名跳过** — 导入时若已存在同名音频，自动跳过并提示
- **删除管理** — 左滑删除音频文件，关联数据级联清理

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.44.0 |
| 状态管理 | Riverpod (AsyncNotifier) |
| 音频引擎 | just_audio + audio_service |
| 数据库 | sqflite |
| 路由 | go_router |
| 文件选择 | file_picker |
| 权限管理 | permission_handler |
| 提示 | fluttertoast |

## 项目结构

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── audio/          # 音频播放服务
│   ├── parser/         # SRT 解析器
│   ├── router/         # 路由配置
│   ├── storage/        # 数据库 & Repository
│   └── theme/          # 主题配置
├── features/
│   ├── batch/          # 批量导入
│   ├── dictation/      # 听写模式
│   ├── favorites/      # 收藏 & 标记
│   ├── files/          # 文件管理 & 单个导入
│   └── player/         # 播放器（状态、控制栏、句子卡片）
└── models/             # 数据模型
```

## 构建

### 环境要求

- Flutter SDK ≥ 3.12.0
- JDK 17
- Android SDK（compileSdk 36）

### 构建 APK

```bash
flutter build apk --release
```

输出路径：`build/app/outputs/flutter-apk/app-release.apk`

### 安装到设备

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
