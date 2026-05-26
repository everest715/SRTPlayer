import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import '../../../providers/app_providers.dart';
import '../data/batch_import_service.dart';

class BatchImportScreen extends ConsumerStatefulWidget {
  const BatchImportScreen({super.key});

  @override
  ConsumerState<BatchImportScreen> createState() => _BatchImportScreenState();
}

class _BatchImportScreenState extends ConsumerState<BatchImportScreen> {
  bool _importing = false;

  Future<void> _importFiles() async {
    setState(() => _importing = true);
    try {
      final audioResult = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      if (audioResult == null || audioResult.files.isEmpty) {
        setState(() => _importing = false);
        return;
      }

      final srtResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt'],
        allowMultiple: true,
      );

      // Build srt map: basename -> path
      final srtMap = <String, String>{};
      if (srtResult != null) {
        for (final f in srtResult.files) {
          final baseName = p.basenameWithoutExtension(f.name);
          if (f.path != null) srtMap[baseName] = f.path!;
        }
      }

      // Match audio with srt by basename
      final pendingFiles = <PendingFile>[];
      for (final af in audioResult.files) {
        if (af.path == null) continue;
        final baseName = p.basenameWithoutExtension(af.name);
        pendingFiles.add(PendingFile(af.path!, srtMap[baseName]));
      }

      if (pendingFiles.isEmpty) {
        Fluttertoast.showToast(msg: '未选择有效的音频文件');
        setState(() => _importing = false);
        return;
      }

      final service = BatchImportService(
        ref.read(audioFileRepositoryProvider),
        ref.read(sentenceRepositoryProvider),
      );
      final importResult = await service.importFiles(pendingFiles);

      ref.invalidate(audioFileListProvider);

      if (mounted) {
        Fluttertoast.showToast(
          msg: '导入完成：${importResult.successCount} 成功，${importResult.failCount} 失败',
          toastLength: Toast.LENGTH_LONG,
        );
        if (importResult.errors.isNotEmpty) {
          _showErrorDialog(importResult.errors);
        } else if (importResult.successCount > 0) {
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
    return Scaffold(
      appBar: AppBar(title: const Text('批量导入')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_music, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('先选择多个 MP3 文件，再选择对应的 SRT 文件'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _importing ? null : _importFiles,
              icon: _importing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file),
              label: Text(_importing ? '导入中...' : '选择音频文件'),
            ),
          ],
        ),
      ),
    );
  }
}
