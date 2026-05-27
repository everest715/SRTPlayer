import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
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

      // 如果未指定目标文件夹，自动以目录名创建 folder（同名则使用现有）
      int? importFolderId = _selectedFolderId;
      if (importFolderId == null) {
        final folderName = p.basename(folderPath);
        final folderRepo = ref.read(folderRepositoryProvider);
        final existing = await folderRepo.getByName(folderName);
        if (existing != null) {
          importFolderId = existing.id;
        } else {
          final newFolder = await folderRepo.create(
            Folder(name: folderName, createdAt: DateTime.now()),
          );
          importFolderId = newFolder.id;
        }
      }

      final service = BatchImportService(
        ref.read(audioFileRepositoryProvider),
        ref.read(sentenceRepositoryProvider),
      );
      final importResult = await service.importFolder(folderPath, folderId: importFolderId);

      ref.invalidate(audioFileListProvider);
      ref.invalidate(folderListProvider);
      if (importFolderId != null) {
        ref.invalidate(folderAudioCountProvider(importFolderId));
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
