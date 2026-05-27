# 文件夹功能设计

## 概述

在主页添加文件夹功能，支持创建文件夹、拖拽音频到文件夹、批量导入时自动归类、左滑删除文件夹（级联删除内部音频）。

## 需求

- 创建文件夹（命名）
- 拖拽音频到文件夹
- 批量导入文件夹时默认归类到对应文件夹
- 文件夹左滑删除，级联删除内部全部音频
- 只支持一层文件夹，不支持嵌套
- 未归入文件夹的音频显示在根目录

## 数据层

### 新增 folders 表

```sql
CREATE TABLE folders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  sortOrder INTEGER NOT NULL DEFAULT 0
)
```

### audio_files 表变更

- 新增 `folderId INTEGER` 列（nullable，null = 根目录未分组）
- 外键：`FOREIGN KEY (folderId) REFERENCES folders(id) ON DELETE CASCADE`

### DB 迁移

- version: 1 → 2
- `onUpgrade`:
  1. `ALTER TABLE audio_files ADD COLUMN folderId INTEGER`
  2. 创建 `folders` 表
  3. 重新创建 `audio_files` 表以添加外键约束（SQLite 不支持 ALTER TABLE ADD CONSTRAINT，需要重建表）

### 新增 Model

```dart
class Folder {
  final int? id;
  final String name;
  final DateTime createdAt;
  final int sortOrder;
}
```

### AudioFile model 变更

- 新增 `int? folderId` 字段
- `toMap` / `fromMap` / `copyWith` 同步更新

### 新增 Repository

`FolderRepository`:
- `getAll()` — 按 sortOrder 排序
- `getById(int id)`
- `create(Folder)`
- `update(Folder)`
- `delete(int id)` — CASCADE 自动删除关联音频

`AudioFileRepository` 变更:
- 新增 `getByFolderId(int? folderId)` — 查询指定文件夹下的音频
- 现有 `getAll()` 仍返回全部音频

### Provider 变更

- 新增 `folderListProvider`（FutureProvider<List<Folder>>）
- 新增 `folderAudioCountProvider`（FamilyFutureProvider，按文件夹 ID 查音频数）
- `audioFileListProvider` 改为返回根目录音频（folderId IS NULL）

### BatchImportService 变更

- `importFolder(String folderPath, {int? folderId})` 新增可选 `folderId` 参数
- 创建 `AudioFile` 时设置 `folderId`

## UI 层

### HomeScreen 改造

当前为扁平 ListView，改为混合列表：

1. **文件夹区域**（列表顶部）— 每个 `ListTile`：左侧文件夹图标 + 名称 + 音频数量，点击进入文件夹详情
2. **根目录音频区域**（文件夹下方）— 未归入文件夹的音频，保持现有 `_AudioFileListTile` 样式

### 文件夹详情页

- 路由：`/folder/:id`
- 显示该文件夹下的音频列表（复用 `_AudioFileListTile`）
- 音频左滑：从文件夹移除（folderId 置 null，回到根目录，不删音频本身）

### 创建文件夹

- 主页 AppBar 的 `PopupMenuButton` 新增「新建文件夹」选项
- 弹出 `AlertDialog` 输入文件夹名称

### 拖拽音频到文件夹

- 音频 `LongPress` 进入拖拽模式（`Draggable` + `DragTarget`）
- 拖到文件夹 `ListTile` 上松手 → 更新 `audio_files.folderId`
- 拖拽过程中文件夹高亮反馈

### 文件夹左滑删除

- 复用现有 `Dismissible` 模式（和音频左滑删除一致）
- 删除确认弹窗：「删除文件夹「XX」及其中的 N 个音频？」
- 确认后 CASCADE 删除（文件夹 + 内部所有音频 + 关联的 sentences/progress/notes）

### 批量导入

- `BatchImportScreen` 选择文件夹后，弹出对话框让用户选择归入哪个已有文件夹（或「不归类」= 根目录）
- 如果从某个文件夹的上下文菜单触发「批量导入到此文件夹」，则自动归入该文件夹，跳过选择

## 路由变更

```dart
GoRoute(
  path: '/folder/:id',
  builder: (context, state) {
    final id = int.parse(state.pathParameters['id']!);
    return FolderDetailScreen(folderId: id);
  },
),
```

## 文件清单

### 新增文件
- `lib/models/folder.dart` — Folder model
- `lib/core/storage/folder_repository.dart` — FolderRepository
- `lib/features/folders/presentation/folder_detail_screen.dart` — 文件夹详情页

### 修改文件
- `lib/core/storage/database.dart` — DB 版本升级 + 迁移
- `lib/models/audio_file.dart` — 加 folderId 字段
- `lib/core/storage/audio_file_repository.dart` — 加 getByFolderId
- `lib/providers/app_providers.dart` — 新增 folder 相关 provider
- `lib/features/files/presentation/home_screen.dart` — 混合列表 + 拖拽 + 文件夹 CRUD
- `lib/features/batch/data/batch_import_service.dart` — 接收 folderId
- `lib/features/batch/presentation/batch_import_screen.dart` — 选择文件夹归类
- `lib/core/router/app_router.dart` — 新增 /folder/:id 路由
