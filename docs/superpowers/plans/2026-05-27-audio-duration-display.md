# 音频时长显示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在音频列表条目右侧显示时长，时长在导入音频时读取并存入数据库。

**Architecture:** 数据库 `audio_files` 表新增 `durationMs` 整数列（DB version 3 升级）。`AudioFile` 模型新增 `durationMs` 字段。导入服务（单文件和批量）在创建 AudioFile 前用 `AudioPlayer` 获取时长。UI 侧在 `_AudioFileListTile` 和 `_FolderAudioListTile` 的 trailing 区域显示格式化时长。

**Tech Stack:** Flutter, Riverpod, sqflite, just_audio

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/models/audio_file.dart` | Modify | 新增 `durationMs` 字段及序列化 |
| `lib/core/storage/database.dart` | Modify | DB version 3：为 `audio_files` 表增加 `durationMs` 列 |
| `lib/features/files/data/file_import_service.dart` | Modify | 单文件导入时获取时长 |
| `lib/features/batch/data/batch_import_service.dart` | Modify | 批量导入时获取时长 |
| `lib/features/files/presentation/home_screen.dart` | Modify | `_AudioFileListTile` trailing 显示时长 |
| `lib/features/folders/presentation/folder_detail_screen.dart` | Modify | `_FolderAudioListTile` trailing 显示时长 |

---

### Task 1: AudioFile 模型新增 durationMs 字段

**Files:**
- Modify: `lib/models/audio_file.dart`

- [ ] **Step 1: 给 AudioFile 添加 durationMs 字段**

在 `AudioFile` 类中新增 `durationMs` 字段（`int?`，单位毫秒），更新构造函数、`toMap()`、`fromMap()`、`copyWith()`。

```dart
// audio_file.dart — 完整替换

class AudioFile {
  final int? id;
  final String fileName;
  final String audioUri;
  final String? srtUri;
  final DateTime createdAt;
  final DateTime? lastPlayedAt;
  final String status; // 'normal' | 'offline'
  final int? folderId;
  final int? durationMs;

  AudioFile({
    this.id,
    required this.fileName,
    required this.audioUri,
    this.srtUri,
    required this.createdAt,
    this.lastPlayedAt,
    this.status = 'normal',
    this.folderId,
    this.durationMs,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'fileName': fileName,
      'audioUri': audioUri,
      'srtUri': srtUri,
      'createdAt': createdAt.toIso8601String(),
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      'status': status,
      'folderId': folderId,
      'durationMs': durationMs,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory AudioFile.fromMap(Map<String, dynamic> map) {
    return AudioFile(
      id: map['id'] as int?,
      fileName: map['fileName'] as String,
      audioUri: map['audioUri'] as String,
      srtUri: map['srtUri'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastPlayedAt: map['lastPlayedAt'] != null
          ? DateTime.parse(map['lastPlayedAt'] as String)
          : null,
      status: map['status'] as String? ?? 'normal',
      folderId: map['folderId'] as int?,
      durationMs: map['durationMs'] as int?,
    );
  }

  AudioFile copyWith({
    int? id,
    String? fileName,
    String? audioUri,
    String? srtUri,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    String? status,
    int? folderId,
    int? durationMs,
  }) {
    return AudioFile(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      audioUri: audioUri ?? this.audioUri,
      srtUri: srtUri ?? this.srtUri,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      status: status ?? this.status,
      folderId: folderId ?? this.folderId,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}
```

- [ ] **Step 2: 确认编译通过**

Run: `cd E:\SelfProjects\SRTPlayer && flutter analyze lib/models/audio_file.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/models/audio_file.dart
git commit -m "feat: add durationMs field to AudioFile model"
```

---

### Task 2: 数据库升级 — audio_files 表增加 durationMs 列

**Files:**
- Modify: `lib/core/storage/database.dart`

- [ ] **Step 1: 数据库 version 升到 3，onUpgrade 增加 durationMs 列**

在 `onCreate` 的 `audio_files` 建表语句中增加 `durationMs INTEGER`。在 `onUpgrade` 中添加 `oldVersion < 3` 的分支执行 `ALTER TABLE audio_files ADD COLUMN durationMs INTEGER`。

修改点：

1. `version: 2` → `version: 3`

2. `onCreate` 中 `audio_files` 建表语句末尾、`FOREIGN KEY` 之前增加一行：
```
durationMs INTEGER,
```

3. `onUpgrade` 方法末尾追加：
```dart
if (oldVersion < 3) {
  await db.execute('ALTER TABLE audio_files ADD COLUMN durationMs INTEGER');
}
```

4. version 2 迁移中新建的 `audio_files` 建表语句也加上 `durationMs INTEGER`（保持一致）。

- [ ] **Step 2: 确认编译通过**

Run: `cd E:\SelfProjects\SRTPlayer && flutter analyze lib/core/storage/database.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/core/storage/database.dart
git commit -m "feat: add durationMs column to audio_files table (DB v3)"
```

---

### Task 3: 单文件导入时获取音频时长

**Files:**
- Modify: `lib/features/files/data/file_import_service.dart`

- [ ] **Step 1: 在 importAudioWithSrt 中用 AudioPlayer 获取时长**

添加 `import 'package:just_audio/just_audio.dart';`。在 `AudioFile` 构造之前，创建临时 `AudioPlayer`，调用 `setFilePath(audioPath)` 获取 `duration`，然后 dispose。

在 `final dbAudioFile = AudioFile(...)` 之前插入：

```dart
int? durationMs;
try {
  final tmpPlayer = AudioPlayer();
  await tmpPlayer.setFilePath(audioPath);
  durationMs = tmpPlayer.duration?.inMilliseconds;
  await tmpPlayer.dispose();
} catch (_) {
  // 获取时长失败不影响导入
}
```

在 `AudioFile(...)` 构造中添加 `durationMs: durationMs`。

- [ ] **Step 2: 确认编译通过**

Run: `cd E:\SelfProjects\SRTPlayer && flutter analyze lib/features/files/data/file_import_service.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/files/data/file_import_service.dart
git commit -m "feat: read audio duration on single-file import"
```

---

### Task 4: 批量导入时获取音频时长

**Files:**
- Modify: `lib/features/batch/data/batch_import_service.dart`

- [ ] **Step 1: 在批量导入循环中用 AudioPlayer 获取时长**

添加 `import 'package:just_audio/just_audio.dart';`。在 for 循环中，`AudioFile(...)` 构造之前，获取时长：

```dart
int? durationMs;
try {
  final tmpPlayer = AudioPlayer();
  await tmpPlayer.setFilePath(mp3File.path);
  durationMs = tmpPlayer.duration?.inMilliseconds;
  await tmpPlayer.dispose();
} catch (_) {
  // 获取时长失败不影响导入
}
```

在 `AudioFile(...)` 构造中添加 `durationMs: durationMs`。

- [ ] **Step 2: 确认编译通过**

Run: `cd E:\SelfProjects\SRTPlayer && flutter analyze lib/features/batch/data/batch_import_service.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/batch/data/batch_import_service.dart
git commit -m "feat: read audio duration on batch import"
```

---

### Task 5: 首页音频列表条目显示时长

**Files:**
- Modify: `lib/features/files/presentation/home_screen.dart`

- [ ] **Step 1: 在 _AudioFileListTile 的 trailing 显示格式化时长**

在 `_AudioFileListTile.build` 中，将 `ListTile` 增加 `trailing`，显示时长文本。格式：`mm:ss`（超过1小时则 `h:mm:ss`）。

在文件顶部无额外 import 需求。

在 `_AudioFileListTile` 类中添加辅助方法：

```dart
String? _formatDuration(int? ms) {
  if (ms == null) return null;
  final duration = Duration(milliseconds: ms);
  final h = duration.inHours;
  final m = duration.inMinutes.remainder(60);
  final s = duration.inSeconds.remainder(60);
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
```

修改 `ListTile`，添加 `trailing`：

```dart
ListTile(
  leading: Icon(
    file.status == 'offline' ? Icons.cloud_off : Icons.audiotrack,
    color: file.status == 'offline' ? Colors.grey : null,
  ),
  title: Text(file.fileName),
  subtitle: file.lastPlayedAt != null
      ? Text('上次：${file.lastPlayedAt!.month}/${file.lastPlayedAt!.day} ${file.lastPlayedAt!.hour}:${file.lastPlayedAt!.minute.toString().padLeft(2, '0')}')
      : null,
  trailing: _formatDuration(file.durationMs) != null
      ? Text(_formatDuration(file.durationMs)!, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))
      : null,
  onTap: file.status == 'offline' ? null : onTap,
),
```

- [ ] **Step 2: 确认编译通过**

Run: `cd E:\SelfProjects\SRTPlayer && flutter analyze lib/features/files/presentation/home_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/files/presentation/home_screen.dart
git commit -m "feat: show audio duration in home screen list tiles"
```

---

### Task 6: 文件夹详情页音频条目显示时长

**Files:**
- Modify: `lib/features/folders/presentation/folder_detail_screen.dart`

- [ ] **Step 1: 在 _FolderAudioListTile 的 trailing 显示格式化时长**

与 Task 5 相同逻辑。添加 `_formatDuration` 辅助方法并在 `ListTile` 中添加 `trailing`。

在 `_FolderAudioListTile` 类中添加：

```dart
String? _formatDuration(int? ms) {
  if (ms == null) return null;
  final duration = Duration(milliseconds: ms);
  final h = duration.inHours;
  final m = duration.inMinutes.remainder(60);
  final s = duration.inSeconds.remainder(60);
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
```

修改 `ListTile`，添加 `trailing`：

```dart
ListTile(
  leading: Icon(
    file.status == 'offline' ? Icons.cloud_off : Icons.audiotrack,
    color: file.status == 'offline' ? Colors.grey : null,
  ),
  title: Text(file.fileName),
  subtitle: file.lastPlayedAt != null
      ? Text('上次：${file.lastPlayedAt!.month}/${file.lastPlayedAt!.day} ${file.lastPlayedAt!.hour}:${file.lastPlayedAt!.minute.toString().padLeft(2, '0')}')
      : null,
  trailing: _formatDuration(file.durationMs) != null
      ? Text(_formatDuration(file.durationMs)!, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))
      : null,
  onTap: file.status == 'offline' ? null : onTap,
),
```

- [ ] **Step 2: 确认编译通过**

Run: `cd E:\SelfProjects\SRTPlayer && flutter analyze lib/features/folders/presentation/folder_detail_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/folders/presentation/folder_detail_screen.dart
git commit -m "feat: show audio duration in folder detail list tiles"
```

---

### Task 7: 提取时长格式化为共享工具函数

**Files:**
- Create: `lib/core/utils/format_utils.dart`
- Modify: `lib/features/files/presentation/home_screen.dart`
- Modify: `lib/features/folders/presentation/folder_detail_screen.dart`

- [ ] **Step 1: 创建 format_utils.dart 并提取 formatDuration**

```dart
String formatDuration(int? ms) {
  if (ms == null) return '';
  final duration = Duration(milliseconds: ms);
  final h = duration.inHours;
  final m = duration.inMinutes.remainder(60);
  final s = duration.inSeconds.remainder(60);
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
```

- [ ] **Step 2: 更新 home_screen.dart 使用 formatDuration**

删除 `_AudioFileListTile` 中的 `_formatDuration` 方法，添加 `import '../../../core/utils/format_utils.dart';`，将 trailing 改为：

```dart
trailing: file.durationMs != null
    ? Text(formatDuration(file.durationMs), style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))
    : null,
```

- [ ] **Step 3: 更新 folder_detail_screen.dart 使用 formatDuration**

删除 `_FolderAudioListTile` 中的 `_formatDuration` 方法，添加 `import '../../../core/utils/format_utils.dart';`，将 trailing 改为：

```dart
trailing: file.durationMs != null
    ? Text(formatDuration(file.durationMs), style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))
    : null,
```

- [ ] **Step 4: 确认编译通过**

Run: `cd E:\SelfProjects\SRTPlayer && flutter analyze`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/format_utils.dart lib/features/files/presentation/home_screen.dart lib/features/folders/presentation/folder_detail_screen.dart
git commit -m "refactor: extract formatDuration to shared utility"
```

---

## Self-Review

**1. Spec coverage:** 
- ✅ 时长存入数据库 → Task 1 (model) + Task 2 (DB schema)
- ✅ 导入时读取时长 → Task 3 (单文件) + Task 4 (批量)
- ✅ 列表条目显示时长 → Task 5 (首页) + Task 6 (文件夹详情)
- ✅ DRY → Task 7 提取共享工具函数

**2. Placeholder scan:** No TBD/TODO/fill-in-later patterns found.

**3. Type consistency:** `durationMs` is `int?` throughout — model, DB column, UI consumption. `formatDuration` takes `int?` and returns `String` (empty for null).
