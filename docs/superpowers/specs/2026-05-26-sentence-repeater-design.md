# 逐句复读播放器（Sentence Repeater）设计文档

**日期**：2026-05-26
**状态**：已确认

---

## 1. 技术选型

| 决策 | 选择 | 理由 |
|------|------|------|
| 跨平台框架 | Flutter | 需求文档推荐，just_audio 生态成熟 |
| 状态管理 | Riverpod | 轻量级，代码简洁，适合 feature-first 组织 |
| 本地数据库 | Isar | 高性能 NoSQL，原生 Flutter 支持，无需原生依赖 |
| 键值存储 | SharedPreferences | 全局偏好设置（变速、主题、字体缩放） |
| 路由 | go_router | 声明式路由，深链接支持 |
| 音频引擎 | just_audio + audio_service | 精确 seekTo、片段循环、后台播放、MediaSession |
| 文件选择 | file_picker + saf_context | Android SAF 支持，兼容 Scoped Storage |
| 目标平台 | Android 优先 | 先 Android 调试通过，再适配 iOS |

## 2. 架构：Feature-first + Clean Architecture

```
lib/
├── core/                        # 跨模块共享
│   ├── audio/                   # 音频引擎封装 (just_audio + audio_service)
│   ├── parser/                  # SRT 解析器
│   ├── storage/                 # 本地持久化 (Isar DB + SharedPreferences)
│   ├── theme/                   # 深色/浅色主题 + 字体缩放
│   └── router/                  # go_router 路由
├── features/
│   ├── player/                  # FR-002~005: 逐句播放、复读、跳转、变速
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── files/                   # FR-001: 文件导入与匹配
│   ├── favorites/               # FR-006: 句子收藏与标记
│   ├── vocabulary/              # FR-007: 生词注释
│   ├── dictation/               # FR-008: 听写模式
│   ├── progress/                # FR-009: 播放进度与历史
│   ├── background/              # FR-010: 后台播放与通知栏
│   └── batch/                   # FR-011: 批量导入与列表管理
└── main.dart
```

每个 feature 模块内部三层：
- **data**：数据源（Isar 集合、文件系统 API）、Repository 实现
- **domain**：实体模型、Repository 接口、UseCase / Provider
- **presentation**：Screen、Widget、Controller（Riverpod Provider）

## 3. 数据模型

### AudioFile
| 字段 | 类型 | 说明 |
|------|------|------|
| id | Id | Isar 自增主键 |
| fileName | String | 显示名 |
| audioUri | String | SAF/Content URI |
| srtUri | String? | 字幕 URI |
| createdAt | DateTime | 导入时间 |
| lastPlayedAt | DateTime? | 最近播放时间 |

### Sentence
| 字段 | 类型 | 说明 |
|------|------|------|
| id | Id | Isar 自增主键 |
| audioFileId | Id | 关联 AudioFile |
| index | int | 句子序号 |
| startTimeMs | int | 起始时间戳 |
| endTimeMs | int | 结束时间戳 |
| text | String | 句子文本 |
| markStatus | MarkStatus | none/diff/focus/mastered |

### PlayProgress
| 字段 | 类型 | 说明 |
|------|------|------|
| id | Id | Isar 自增主键 |
| audioFileId | Id | 关联 AudioFile |
| sentenceIdx | int | 当前句索引 |
| positionMs | int | 句内位置 |

### SpeedSetting
| 字段 | 类型 | 说明 |
|------|------|------|
| id | Id | Isar 自增主键 |
| audioFileId | Id | 关联 AudioFile |
| speed | double | 播放速度 |

### WordNote
| 字段 | 类型 | 说明 |
|------|------|------|
| id | Id | Isar 自增主键 |
| sentenceId | Id | 关联 Sentence |
| word | String | 查词原文 |
| definition | String | 释义 |
| source | DictSource | local/online |

## 4. 核心流程

### 文件导入
```
用户选择 MP3 → file_picker
  ↓
同目录自动扫描同名 .srt → 有则自动关联
  ↓ 无则手动选择 SRT
SRT 解析 → 错误行提示，跳过异常条目
  ↓
持久化 AudioFile + Sentences → 进入播放页
```

### 播放状态机
```
         ┌──────────┐
    ┌────│  idle    │◄──── audio_service 初始化
    │    └────┬─────┘
    │         │ play(sentenceIdx)
    │    ┌────▼─────┐
    │    │ playing  │◄────┐ resume
    │    └────┬─────┘     │
    │    pause│      ┌────┴────┐
    │    ┌────▼─────┐│ looping │ (A-B Loop)
    │    │ paused   │└─────────┘
    │    └────┬─────┘  到句末自动重播
    │         │ sentenceEnd
    │    ┌────▼─────┐
    │    │ ended    │──→ 播放下句 / 停止
    │    └──────────┘
    └── seekTo / nextSentence / prevSentence
```

### Riverpod Provider 结构
```
audioFileProvider        — 当前打开的音频文件
sentenceListProvider    — 当前文件的句子列表
playerStateProvider     — 播放状态 (idle/playing/paused/looping)
currentSentenceProvider — 当前播放的句子索引
speedProvider           — 当前变速档位
progressProvider        — 播放进度 (句内 ms)
```

## 5. UI 屏幕

| 屏幕 | 路由 | 说明 |
|------|------|------|
| HomeScreen | `/` | 课程列表 + 导入入口（空状态时显示引导） |
| PlayerScreen | `/player/:id` | 核心播放界面（句子列表 + 控制栏） |
| DictationScreen | `/player/:id/dictation` | 听写模式（隐藏原文，输入对照） |

### PlayerScreen 布局
- **AppBar**：课程名 / 变速指示器
- **SentenceList**：可滚动句子卡片，当前句高亮 + 自动居中
- **ControlBar**：[⏮] [⏯] [⏭] [🔁] [⚡]
- **SentenceProgressBar**：当前句内微进度

### 句子卡片交互
- 单击 → 播放该句
- 双击 → 切换复读
- 长按 → 弹出菜单：收藏/标记生词/听写/复制

### 变速弹窗
底部 Sheet，0.5x / 0.7x / 0.8x / 1.0x / 1.2x / 1.5x / 2.0x 七个档位。

## 6. 异常处理

| 场景 | 处理方式 |
|------|----------|
| SRT 解析错误 | 跳过异常条目，Toast 提示行号 + 错误类型 |
| 音频中断（来电/闹钟） | 监听 audio_session interruption，自动暂停并保存位置；恢复后 SnackBar 询问继续 |
| 文件丢失/移动 | URI 校验失败 → 列表项标记"离线"，不崩溃 |
| 空字幕文件 | 提示"字幕为空"，仍可线性播放 |

## 7. 后台播放 (FR-010)

- 使用 audio_service 注册 MediaSession
- 通知栏：当前句子文本（截断 30 字）+ 播放/暂停/上下句
- 锁屏媒体控件同步
- MediaButtonReceiver 映射耳机/蓝牙按键为上下句

## 8. 功能范围

### P0（必须）
- FR-001 文件导入
- FR-002 逐句播放
- FR-003 单句复读（A-B Loop）
- FR-004 上下句跳转
- FR-005 变速播放

### P1（重要）
- FR-006 句子收藏与标记
- FR-007 生词注释
- FR-008 听写模式
- FR-009 播放进度与历史

### P2（可选）
- FR-010 后台播放与通知栏控制
- FR-011 批量导入与列表管理

## 9. 关键依赖

```yaml
dependencies:
  flutter_riverpod: ^2.x
  just_audio: ^0.9.x
  audio_service: ^0.18.x
  audio_session: ^0.1.x
  isar: ^4.x
  isar_flutter_libs: ^4.x
  shared_preferences: ^2.x
  go_router: ^14.x
  file_picker: ^8.x
  path: ^1.x
```
