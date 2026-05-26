import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../models/audio_file.dart';
import '../../../providers/app_providers.dart';
import '../data/file_import_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _importing = false;

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
        context.go('/player/${result.audioFile!.id}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(audioFileListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('逐句复读播放器'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'batch') {
                context.go('/batch-import');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'batch', child: Text('批量导入')),
            ],
          ),
        ],
      ),
      body: filesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (files) {
          if (files.isEmpty) {
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
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return _AudioFileListTile(file: file, onTap: () => context.go('/player/${file.id}'));
            },
          );
        },
      ),
      floatingActionButton: filesAsync.value?.isNotEmpty == true
          ? FloatingActionButton(
              onPressed: _importing ? null : _importFile,
              child: const Icon(Icons.add),
            )
          : null,
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
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(context, ref),
        ),
        onTap: file.status == 'offline' ? null : onTap,
      ),
    );
  }
}
