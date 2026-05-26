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
        if (result.errors.isNotEmpty) {
          Fluttertoast.showToast(
            msg: '导入完成，${result.errors.length} 条字幕解析异常',
            toastLength: Toast.LENGTH_LONG,
          );
        }
        ref.invalidate(audioFileListProvider);
        context.go('/player/${result.audioFile.id}');
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

class _AudioFileListTile extends StatelessWidget {
  final AudioFile file;
  final VoidCallback onTap;

  const _AudioFileListTile({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        file.status == 'offline' ? Icons.cloud_off : Icons.audiotrack,
        color: file.status == 'offline' ? Colors.grey : null,
      ),
      title: Text(file.fileName),
      subtitle: file.lastPlayedAt != null
          ? Text('上次：${file.lastPlayedAt!.month}/${file.lastPlayedAt!.day} ${file.lastPlayedAt!.hour}:${file.lastPlayedAt!.minute.toString().padLeft(2, '0')}')
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: file.status == 'offline' ? null : onTap,
    );
  }
}
