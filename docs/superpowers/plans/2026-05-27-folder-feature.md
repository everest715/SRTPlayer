# 文件夹功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在主页添加文件夹功能，支持创建文件夹、拖拽音频到文件夹、批量导入时自动归类、左滑删除文件夹（级联删除内部音频）。

**Architecture:** 新建 `folders` 表，`audio_files` 表加 `folderId` 外键。DB version 1→2，通过重建 `audio_files` 表添加外键约束。UI 层 HomeScreen 改为混合列表（文件夹+根目录音频），新增文件夹详情页。

**Tech Stack:** Flutter, Riverpod, sqflite, go_router

---

### Task 1: DB 迁移 — version 1→2，新增 folders 表 + audio_files 加 folderId

**Files:**
- Modify: `lib/core/storage/database.dart`

- [ ] **Step 1: 修改 `database.dart`，升级 version 并添加 onCreate 和 onUpgrade**

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  static Database? _instance;

  static Future<Database> get instance async {
    if (_instance != null) return _instance!;
    _instance = await _initDb();
    return _instance!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'srt_player.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE folders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            sortOrder INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE audio_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fileName TEXT NOT NULL,
            audioUri TEXT NOT NULL,
            srtUri TEXT,
            createdAt TEXT NOT NULL,
            lastPlayedAt TEXT,
            status TEXT NOT NULL DEFAULT 'normal',
            folderId INTEGER,
            FOREIGN KEY (folderId) REFERENCES folders(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE sentences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            audioFileId INTEGER NOT NULL,
            idx INTEGER NOT NULL,
            startTimeMs INTEGER NOT NULL,
            endTimeMs INTEGER NOT NULL,
            text TEXT NOT NULL,
            markStatus TEXT NOT NULL DEFAULT 'none',
            FOREIGN KEY (audioFileId) REFERENCES audio_files(id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_sentences_audio ON sentences(audioFileId)',
        );
        await db.execute('''
          CREATE TABLE play_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            audioFileId INTEGER NOT NULL UNIQUE,
            sentenceIdx INTEGER NOT NULL,
            positionMs INTEGER NOT NULL,
            FOREIGN KEY (audioFileId) REFERENCES audio_files(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE speed_settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            audioFileId INTEGER NOT NULL UNIQUE,
            speed REAL NOT NULL,
            FOREIGN KEY (audioFileId) REFERENCES audio_files(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE word_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sentenceId INTEGER NOT NULL,
            word TEXT NOT NULL,
            definition TEXT NOT NULL,
            source TEXT NOT NULL DEFAULT 'local',
            FOREIGN KEY (sentenceId) REFERENCES sentences(id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_word_notes_sentence ON word_notes(sentenceId)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // 1. 创建 folders 表
          await db.execute('''
            CREATE TABLE folders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              createdAt TEXT NOT NULL,
              sortOrder INTEGER NOT NULL DEFAULT 0
            )
          ''');

          // 2. 重建 audio_files 表以添加 folderId 外键
          await db.execute('ALTER TABLE audio_files RENAME TO audio_files_old');
          await db.execute('''
            CREATE TABLE audio_files (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              fileName TEXT NOT NULL,
              audioUri TEXT NOT NULL,
              srtUri TEXT,
              createdAt TEXT NOT NULL,
              lastPlayedAt TEXT,
              status TEXT NOT NULL DEFAULT 'normal',
              folderId INTEGER,
              FOREIGN KEY (folderId) REFERENCES folders(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            INSERT INTO audio_files (id, fileName, audioUri, srtUri, createdAt, lastPlayedAt, status)
            SELECT id, fileName, audioUri, srtUri, createdAt, lastPlayedAt, status FROM audio_files_old
          ''');
          await db.execute('DROP TABLE audio_files_old');
        }
      },
    );
  }
}
```

- [ ] **Step 2: 卸载设备上的旧 app 确保干净数据库，运行验证**

Run: `C:\flutter-sdk\bin\flutter.bat run -d 3e949fcd`

验证 app 正常启动，无报错。

- [ ] **Step 3: Commit**

```bash
git add lib/core/storage/database.dart
git commit -m "feat(数据库): 升级到 v2，新增 folders 表和 audio_files.folderId"
```

---

### Task 2: Folder model

**Files:**
- Create: `lib/models/folder.dart`

- [ ] **Step 1: 创建 Folder model**

```dart
class Folder {
  final int? id;
  final String name;
  final DateTime createdAt;
  final int sortOrder;

  Folder({
    this.id,
    required this.name,
    required this.createdAt,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'sortOrder': sortOrder,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  Folder copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    int? sortOrder,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/folder.dart
git commit -m "feat: 添加 Folder model"
```

---

### Task 3: AudioFile model 加 folderId 字段

**Files:**
- Modify: `lib/models/audio_file.dart`

- [ ] **Step 1: 在 AudioFile 中添加 folderId 字段**

修改 `AudioFile` 类，添加 `folderId`：

```dart
class AudioFile {
  final int? id;
  final String fileName;
  final String audioUri;
  final String? srtUri;
  final DateTime createdAt;
  final DateTime? lastPlayedAt;
  final String status; // 'normal' | 'offline'
  final int? folderId;

  AudioFile({
    this.id,
    required this.fileName,
    required this.audioUri,
    this.srtUri,
    required this.createdAt,
    this.lastPlayedAt,
    this.status = 'normal',
    this.folderId,
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
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/audio_file.dart
git commit -m "feat(AudioFile): 添加 folderId 字段"
```

---

### Task 4: FolderRepository

**Files:**
- Create: `lib/core/storage/folder_repository.dart`

- [ ] **Step 1: 创建 FolderRepository**

```dart
import 'package:sqflite/sqflite.dart';
import '../../models/folder.dart';
import 'database.dart';

class FolderRepository {
  Future<Database> _db() => AppDatabase.instance;

  Future<List<Folder>> getAll() async {
    final db = await _db();
    final maps = await db.query('folders', orderBy: 'sortOrder ASC, createdAt ASC');
    return maps.map((m) => Folder.fromMap(m)).toList();
  }

  Future<Folder?> getById(int id) async {
    final db = await _db();
    final maps = await db.query('folders', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Folder.fromMap(maps.first);
  }

  Future<Folder> create(Folder folder) async {
    final db = await _db();
    final id = await db.insert('folders', folder.toMap());
    return folder.copyWith(id: id);
  }

  Future<void> update(Folder folder) async {
    final db = await _db();
    await db.update('folders', folder.toMap(), where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db();
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getAudioCount(int folderId) async {
    final db = await _db();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM audio_files WHERE folderId = ?',
      [folderId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/storage/folder_repository.dart
git commit -m "feat: 添加 FolderRepository"
```

---

### Task 5: AudioFileRepository 加 getByFolderId + updateFolderId

**Files:**
- Modify: `lib/core/storage/audio_file_repository.dart`

- [ ] **Step 1: 在 AudioFileRepository 中添加 getByFolderId 和 updateFolderId 方法**

在现有 `AudioFileRepository` 类末尾（`delete` 方法之后）添加：

```dart
  Future<List<AudioFile>> getByFolderId(int? folderId) async {
    final db = await _db();
    final maps = folderId == null
        ? await db.query('audio_files', where: 'folderId IS NULL', orderBy: 'lastPlayedAt DESC, createdAt DESC')
        : await db.query('audio_files', where: 'folderId = ?', whereArgs: [folderId], orderBy: 'lastPlayedAt DESC, createdAt DESC');
    return maps.map((m) => AudioFile.fromMap(m)).toList();
  }

  Future<void> updateFolderId(int audioFileId, int? folderId) async {
    final db = await _db();
    await db.update('audio_files', {'folderId': folderId}, where: 'id = ?', whereArgs: [audioFileId]);
  }
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/storage/audio_file_repository.dart
git commit -m "feat(AudioFileRepository): 添加 getByFolderId 和 updateFolderId"
```

---

### Task 6: Providers — 添加 folder 相关 provider

**Files:**
- Modify: `lib/providers/app_providers.dart`

- [ ] **Step 1: 添加 folder 相关 import 和 providers**

在文件顶部添加 import：

```dart
import '../core/storage/folder_repository.dart';
import '../models/folder.dart';
```

在 `audioFileListProvider` 之前添加：

```dart
final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepository();
});

final folderListProvider = FutureProvider<List<Folder>>((ref) {
  final repo = ref.read(folderRepositoryProvider);
  return repo.getAll();
});

final folderAudioCountProvider = FutureProvider.family<int, int>((ref, folderId) {
  final repo = ref.read(folderRepositoryProvider);
  return repo.getAudioCount(folderId);
});
```

修改 `audioFileListProvider`，只返回根目录（未分组）的音频：

```dart
final audioFileListProvider = FutureProvider<List<AudioFile>>((ref) {
  final repo = ref.read(audioFileRepositoryProvider);
  return repo.getByFolderId(null).then((list) => list..sort((a, b) => a.fileName.compareTo(b.fileName)));
});
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/app_providers.dart
git commit -m "feat(providers): 添加 folder 相关 provider，audioFileListProvider 改为根目录音频"
```

---

### Task 7: 路由 — 添加 /folder/:id

**Files:**
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: 添加 FolderDetailScreen import 和路由**

文件顶部添加：

```dart
import '../../features/folders/presentation/folder_detail_screen.dart';
```

在 `routes` 列表中，`/batch-import` 路由之后添加：

```dart
    GoRoute(
      path: '/folder/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return FolderDetailScreen(folderId: id);
      },
    ),
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(router): 添加 /folder/:id 路由"
```

---

### Task 8: FolderDetailScreen — 文件夹详情页

**Files:**
- Create: `lib/features/folders/presentation/folder_detail_screen.dart`

- [ ] **Step 1: 创建 FolderDetailScreen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/audio_file.dart';
import '../../../providers/app_providers.dart';

class FolderDetailScreen extends ConsumerStatefulWidget {
  final int folderId;

  const FolderDetailScreen({super.key, required this.folderId});

  @override
  ConsumerState<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends ConsumerState<FolderDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final folderAsync = ref.watch(folderListProvider);
    final folder = folderAsync.value?.where((f) => f.id == widget.folderId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(folder?.name ?? '文件夹'),
      ),
      body: _FolderAudioList(folderId: widget.folderId),
    );
  }
}

class _FolderAudioList extends ConsumerStatefulWidget {
  final int folderId;

  const _FolderAudioList({required this.folderId});

  @override
  ConsumerState<_FolderAudioList> createState() => _FolderAudioListState();
}

class _FolderAudioListState extends ConsumerState<_FolderAudioList> {
  late FutureProvider<List<AudioFile>> _folderAudioProvider;

  @override
  void initState() {
    super.initState();
    _folderAudioProvider = FutureProvider<List<AudioFile>>((ref) {
      final repo = ref.read(audioFileRepositoryProvider);
      return repo.getByFolderId(widget.folderId).then((list) => list..sort((a, b) => a.fileName.compareTo(b.fileName)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(_folderAudioProvider);

    return filesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (files) {
        if (files.isEmpty) {
          return const Center(child: Text('文件夹为空'));
        }
        return ListView.builder(
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return _FolderAudioListTile(
              file: file,
              onTap: () => context.push('/player/${file.id}'),
              onRemoved: () {
                ref.invalidate(_folderAudioProvider);
                ref.invalidate(audioFileListProvider);
              },
            );
          },
        );
      },
    );
  }
}

class _FolderAudioListTile extends ConsumerWidget {
  final AudioFile file;
  final VoidCallback onTap;
  final VoidCallback onRemoved;

  const _FolderAudioListTile({required this.file, required this.onTap, required this.onRemoved});

  Future<bool> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移出文件夹'),
        content: Text('将「${file.fileName}」移出此文件夹？\n音频不会被删除，会回到根目录。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('移出')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(audioFileRepositoryProvider).updateFolderId(file.id!, null);
      onRemoved();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(file.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.orange,
        child: const Icon(Icons.folder_off, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmRemove(context, ref),
      onDismissed: (_) {},
      child: ListTile(
        leading: Icon(
          file.status == 'offline' ? Icons.cloud_off : Icons.audiotrack,
          color: file.status == 'offline' ? Colors.grey : null,
        ),
        title: Text(file.fileName),
        subtitle: file.lastPlayedAt != null
            ? Text('上次：${file.lastPlayedAt!.month}/${file.lastPlayedAt!.day} ${file.lastPlayedAt!.hour}:${file.lastPlayedAt!.minute.toString().padLeft(2, '0')}')
            : null,
        onTap: file.status == 'offline' ? null : onTap,
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/folders/presentation/folder_detail_screen.dart
git commit -m "feat: 添加 FolderDetailScreen 文件夹详情页"
```

---

### Task 9: HomeScreen 改造 — 混合列表 + 文件夹 CRUD + 拖拽

**Files:**
- Modify: `lib/features/files/presentation/home_screen.dart`

这是最大的改动，将 HomeScreen 从扁平列表改为：文件夹区域（顶部）+ 根目录音频区域（下方），支持创建文件夹、拖拽音频到文件夹、文件夹左滑删除。

- [ ] **Step 1: 重写 home_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../models/audio_file.dart';
import '../../../models/folder.dart';
import '../../../providers/app_providers.dart';
import '../data/file_import_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _importing = false;
  bool _dragging = false;
  int? _dragOverFolderId;

  Future<void> _importFile() async {
    setState(() => _importing = true);
    try {
      final importService = FileImportService(
        ref.read(audioFileRepositoryProvider),
        ref.read(sentenceRepositoryProvider),
      );
      final result = await importService.importAudioWithSrt();
      if (result != null) {
        if (result.isDuplicate) {
          Fluttertoast.showToast(msg: '「${result.duplicateName}」已存在，已跳过导入');
          return;
        }
        if (result.errors.isNotEmpty) {
          Fluttertoast.showToast(
            msg: '导入完成，${result.errors.length} 条字幕解析异常',
            toastLength: Toast.LENGTH_LONG,
          );
        }
        ref.invalidate(audioFileListProvider);
        context.push('/player/${result.audioFile!.id}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _createFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('新建文件夹'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '文件夹名称'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      final repo = ref.read(folderRepositoryProvider);
      await repo.create(Folder(name: name, createdAt: DateTime.now()));
      ref.invalidate(folderListProvider);
    }
  }

  Future<bool> _confirmDeleteFolder(Folder folder, int audioCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除确认'),
        content: Text('确定要删除文件夹「${folder.name}」吗？\n其中的 $audioCount 个音频将一并删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = ref.read(folderRepositoryProvider);
      await repo.delete(folder.id!);
      ref.invalidate(folderListProvider);
      ref.invalidate(audioFileListProvider);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(audioFileListProvider);
    final foldersAsync = ref.watch(folderListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('逐句复读播放器'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'batch') {
                context.go('/batch-import');
              } else if (value == 'new_folder') {
                _createFolder();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'new_folder', child: Text('新建文件夹')),
              const PopupMenuItem(value: 'batch', child: Text('批量导入')),
            ],
          ),
        ],
      ),
      body: filesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (files) {
          final folders = foldersAsync.value ?? [];
          final hasContent = folders.isNotEmpty || files.isNotEmpty;

          if (!hasContent) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.headphones, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('选择 MP3 与字幕', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _importing ? null : _importFile,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('导入音频'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: folders.length + files.length,
            itemBuilder: (context, index) {
              if (index < folders.length) {
                final folder = folders[index];
                return _buildFolderTile(folder);
              }
              final file = files[index - folders.length];
              return _buildAudioTile(file);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _importing ? null : _importFile,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFolderTile(Folder folder) {
    final countAsync = ref.watch(folderAudioCountProvider(folder.id!));
    final count = countAsync.valueOrNull ?? 0;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        setState(() => _dragOverFolderId = folder.id);
        return true;
      },
      onLeave: (_) {
        setState(() => _dragOverFolderId = null);
      },
      onAcceptWithDetails: (details) async {
        setState(() => _dragOverFolderId = null);
        await ref.read(audioFileRepositoryProvider).updateFolderId(details.data, folder.id);
        ref.invalidate(audioFileListProvider);
        ref.invalidate(folderAudioCountProvider(folder.id!));
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = _dragOverFolderId == folder.id;
        return Dismissible(
          key: ValueKey('folder_${folder.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) => _confirmDeleteFolder(folder, count),
          onDismissed: (_) {},
          child: Container(
            color: isHovered ? Theme.of(context).colorScheme.primaryContainer : null,
            child: ListTile(
              leading: Icon(
                isHovered ? Icons.folder_open : Icons.folder,
                color: isHovered ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(folder.name),
              subtitle: Text('$count 个音频'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/folder/${folder.id}'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioTile(AudioFile file) {
    return LongPressDraggable<int>(
      data: file.id,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.audiotrack, size: 20),
              const SizedBox(width: 8),
              Text(file.fileName, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _AudioFileListTile(file: file, onTap: () => context.push('/player/${file.id}')),
      ),
      onDragStarted: () => setState(() => _dragging = true),
      onDragEnd: (_) => setState(() {
        _dragging = false;
        _dragOverFolderId = null;
      }),
      child: _AudioFileListTile(file: file, onTap: () => context.push('/player/${file.id}')),
    );
  }
}

class _AudioFileListTile extends ConsumerWidget {
  final AudioFile file;
  final VoidCallback onTap;

  const _AudioFileListTile({required this.file, required this.onTap});

  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除确认'),
        content: Text('确定要删除「${file.fileName}」吗？\n相关字幕、进度和笔记将一并删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(audioFileRepositoryProvider).delete(file.id!);
      ref.invalidate(audioFileListProvider);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(file.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context, ref),
      onDismissed: (_) {},
      child: ListTile(
        leading: Icon(
          file.status == 'offline' ? Icons.cloud_off : Icons.audiotrack,
          color: file.status == 'offline' ? Colors.grey : null,
        ),
        title: Text(file.fileName),
        subtitle: file.lastPlayedAt != null
            ? Text('上次：${file.lastPlayedAt!.month}/${file.lastPlayedAt!.day} ${file.lastPlayedAt!.hour}:${file.lastPlayedAt!.minute.toString().padLeft(2, '0')}')
            : null,
        onTap: file.status == 'offline' ? null : onTap,
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/files/presentation/home_screen.dart
git commit -m "feat(主页): 改造为混合列表，支持文件夹 CRUD 和拖拽音频到文件夹"
```

---

### Task 10: BatchImportService 支持 folderId

**Files:**
- Modify: `lib/features/batch/data/batch_import_service.dart`

- [ ] **Step 1: 给 importFolder 方法添加可选 folderId 参数**

将 `importFolder` 方法签名从：

```dart
Future<BatchImportResult> importFolder(String folderPath) async {
```

改为：

```dart
Future<BatchImportResult> importFolder(String folderPath, {int? folderId}) async {
```

将方法内创建 `AudioFile` 的代码从：

```dart
        final dbFile = await _audioFileRepo.create(AudioFile(
          fileName: fileName,
          audioUri: mp3File.path,
          srtUri: srtPath,
          createdAt: DateTime.now(),
        ));
```

改为：

```dart
        final dbFile = await _audioFileRepo.create(AudioFile(
          fileName: fileName,
          audioUri: mp3File.path,
          srtUri: srtPath,
          createdAt: DateTime.now(),
          folderId: folderId,
        ));
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/batch/data/batch_import_service.dart
git commit -m "feat(BatchImportService): 支持导入时指定 folderId"
```

---

### Task 11: BatchImportScreen — 选择文件夹归类

**Files:**
- Modify: `lib/features/batch/presentation/batch_import_screen.dart`

- [ ] **Step 1: 重写 BatchImportScreen，添加文件夹选择功能**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../providers/app_providers.dart';
import '../../../models/folder.dart';
import '../data/batch_import_service.dart';

class BatchImportScreen extends ConsumerStatefulWidget {
  final int? targetFolderId;

  const BatchImportScreen({super.key, this.targetFolderId});

  @override
  ConsumerState<BatchImportScreen> createState() => _BatchImportScreenState();
}

class _BatchImportScreenState extends ConsumerState<BatchImportScreen> {
  bool _importing = false;
  int? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.targetFolderId;
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.audio.status.isGranted) return true;
    final result = await Permission.audio.request();
    if (result.isGranted) return true;

    if (await Permission.storage.status.isGranted) return true;
    final fallback = await Permission.storage.request();
    return fallback.isGranted;
  }

  Future<void> _importFolder() async {
    final granted = await _requestStoragePermission();
    if (!granted) {
      Fluttertoast.showToast(msg: '需要存储权限才能扫描文件夹');
      return;
    }

    setState(() => _importing = true);
    try {
      final folderPath = await FilePicker.platform.getDirectoryPath();
      if (folderPath == null) {
        setState(() => _importing = false);
        return;
      }

      final service = BatchImportService(
        ref.read(audioFileRepositoryProvider),
        ref.read(sentenceRepositoryProvider),
      );
      final importResult = await service.importFolder(folderPath, folderId: _selectedFolderId);

      ref.invalidate(audioFileListProvider);
      ref.invalidate(folderListProvider);
      if (_selectedFolderId != null) {
        ref.invalidate(folderAudioCountProvider(_selectedFolderId!));
      }

      if (mounted) {
        final skipMsg = importResult.skippedCount > 0 ? '，${importResult.skippedCount} 已存在跳过' : '';
        Fluttertoast.showToast(
          msg: '导入完成：${importResult.successCount} 成功，${importResult.failCount} 失败$skipMsg',
          toastLength: Toast.LENGTH_LONG,
        );
        if (importResult.errors.isNotEmpty) {
          _showErrorDialog(importResult.errors);
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '批量导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showErrorDialog(List<String> errors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入错误'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: errors.length,
            itemBuilder: (_, i) => Text(errors[i], style: const TextStyle(fontSize: 12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/');
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(folderListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('批量导入')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('选择包含 MP3+SRT 配对的文件夹'),
              const SizedBox(height: 24),
              // 归类选择
              if (widget.targetFolderId == null)
                foldersAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (folders) {
                    if (folders.isEmpty) return const SizedBox.shrink();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<int?>(
                          value: _selectedFolderId,
                          decoration: const InputDecoration(
                            labelText: '归入文件夹',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('不归类（根目录）')),
                            ...folders.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))),
                          ],
                          onChanged: (v) => setState(() => _selectedFolderId = v),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _importing ? null : _importFolder,
                icon: _importing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file),
                label: Text(_importing ? '导入中...' : '选择文件夹'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/batch/presentation/batch_import_screen.dart
git commit -m "feat(批量导入): 支持选择文件夹归类，可指定 targetFolderId"
```

---

### Task 12: 路由适配 — BatchImportScreen 支持 targetFolderId 参数

**Files:**
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: 更新 BatchImportScreen 路由以传递 extra 参数**

将 `/batch-import` 路由从：

```dart
    GoRoute(
      path: '/batch-import',
      builder: (context, state) => const BatchImportScreen(),
    ),
```

改为：

```dart
    GoRoute(
      path: '/batch-import',
      builder: (context, state) => BatchImportScreen(
        targetFolderId: state.extra as int?,
      ),
    ),
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(router): BatchImportScreen 支持 targetFolderId 参数传递"
```

---

### Task 13: 构建验证 + 最终提交

- [ ] **Step 1: 卸载设备上的旧 app（确保干净 DB），运行验证**

Run:
```bash
$env:JAVA_HOME = "D:\Android\jdk-17.0.19+10"; C:\flutter-sdk\bin\flutter.bat run -d 3e949fcd
```

验证点：
1. App 正常启动，无报错
2. 主页显示空状态
3. PopupMenu 中出现「新建文件夹」选项
4. 点击「新建文件夹」输入名称，文件夹出现在列表顶部
5. 点击文件夹进入详情页
6. 导入音频到根目录
7. 长按拖拽音频到文件夹，文件夹高亮反馈
8. 松手后音频从根目录消失，进入文件夹
9. 文件夹详情页显示已归类的音频
10. 文件夹左滑删除，确认后级联删除
11. 批量导入时出现文件夹选择下拉框

- [ ] **Step 2: 构建 release APK 并安装**

Run:
```bash
$env:JAVA_HOME = "D:\Android\jdk-17.0.19+10"; C:\flutter-sdk\bin\flutter.bat build apk --release
D:\Android\SDK\platform-tools\adb.exe install -r "E:\SelfProjects\SRTPlayer\build\app\outputs\flutter-apk\app-release.apk"
```

- [ ] **Step 3: 最终 commit（如有未提交的更改）**

```bash
git add -A
git commit -m "feat(文件夹): 完整文件夹功能 — 创建/拖拽/批量导入归类/级联删除"
```
