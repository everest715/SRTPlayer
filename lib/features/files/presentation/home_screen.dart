import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../models/audio_file.dart';
import '../../../models/folder.dart';
import '../../../providers/app_providers.dart';
import '../data/file_import_service.dart';
import '../../../core/utils/format_utils.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _importing = false;
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
      final existing = await repo.getByName(name);
      if (existing != null) {
        Fluttertoast.showToast(msg: '文件夹「$name」已存在');
        return;
      }
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
      onDragEnd: (_) => setState(() => _dragOverFolderId = null),
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
    final completedAsync = ref.watch(audioCompletedProvider(file.id!));
    final isCompleted = completedAsync.valueOrNull ?? false;

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
          file.status == 'offline'
              ? Icons.cloud_off
              : isCompleted
                  ? Icons.check_circle
                  : Icons.audiotrack,
          color: file.status == 'offline'
              ? Colors.grey
              : isCompleted
                  ? Colors.green
                  : null,
        ),
        title: Text(file.fileName),
        subtitle: file.lastPlayedAt != null
            ? Text('上次：${file.lastPlayedAt!.month}/${file.lastPlayedAt!.day} ${file.lastPlayedAt!.hour}:${file.lastPlayedAt!.minute.toString().padLeft(2, '0')}')
            : null,
        trailing: file.durationMs != null
            ? Text(formatDuration(file.durationMs), style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))
            : null,
        onTap: file.status == 'offline' ? null : onTap,
      ),
    );
  }
}
