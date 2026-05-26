import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../providers/app_providers.dart';
import '../data/batch_import_service.dart';

class BatchImportScreen extends ConsumerStatefulWidget {
  const BatchImportScreen({super.key});

  @override
  ConsumerState<BatchImportScreen> createState() => _BatchImportScreenState();
}

class _BatchImportScreenState extends ConsumerState<BatchImportScreen> {
  bool _importing = false;

  Future<void> _importFolder() async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result == null) {
        setState(() => _importing = false);
        return;
      }

      final service = BatchImportService(
        ref.read(audioFileRepositoryProvider),
        ref.read(sentenceRepositoryProvider),
      );
      final importResult = await service.importFolder(result);

      ref.invalidate(audioFileListProvider);

      if (mounted) {
        Fluttertoast.showToast(
          msg: '导入完成：${importResult.successCount} 成功，${importResult.failCount} 失败',
          toastLength: Toast.LENGTH_LONG,
        );
        if (importResult.errors.isNotEmpty) {
          _showErrorDialog(importResult.errors);
        } else {
          Navigator.pop(context);
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
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定'))],
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
            const Icon(Icons.folder_open, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('选择包含 MP3+SRT 配对的文件夹'),
            const SizedBox(height: 24),
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
    );
  }
}
