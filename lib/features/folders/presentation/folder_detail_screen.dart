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
