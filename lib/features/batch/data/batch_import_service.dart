import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:just_audio/just_audio.dart';
import '../../../core/parser/srt_parser.dart';
import '../../../core/storage/audio_file_repository.dart';
import '../../../core/storage/sentence_repository.dart';
import '../../../models/audio_file.dart';
import '../../../models/sentence.dart';

class BatchImportResult {
  final int successCount;
  final int failCount;
  final int skippedCount;
  final List<String> errors;

  BatchImportResult({required this.successCount, required this.failCount, required this.errors, this.skippedCount = 0});
}

class BatchImportService {
  final AudioFileRepository _audioFileRepo;
  final SentenceRepository _sentenceRepo;

  BatchImportService(this._audioFileRepo, this._sentenceRepo);

  Future<BatchImportResult> importFolder(String folderPath, {int? folderId}) async {
    int success = 0;
    int fail = 0;
    int skipped = 0;
    final errors = <String>[];

    final dir = Directory(folderPath);
    if (!dir.existsSync()) {
      return BatchImportResult(successCount: 0, failCount: 0, errors: ['目录不存在']);
    }

    final mp3Files = dir.listSync()
        .where((f) => p.extension(f.path).toLowerCase() == '.mp3')
        .toList();

    if (mp3Files.isEmpty) {
      return BatchImportResult(successCount: 0, failCount: 0, errors: ['目录中没有 MP3 文件']);
    }

    final existingNames = (await _audioFileRepo.getAll()).map((f) => f.fileName).toSet();

    for (final mp3File in mp3Files) {
      try {
        final fileName = p.basenameWithoutExtension(mp3File.path);

        if (existingNames.contains(fileName)) {
          skipped++;
          continue;
        }

        final srtPath = p.join(dir.path, '$fileName.srt');
        if (!File(srtPath).existsSync()) {
          errors.add('$fileName: 未找到匹配的 SRT 文件');
          fail++;
          continue;
        }

        final parseResult = SrtParser.parseWithErrors(await File(srtPath).readAsString());
        if (parseResult.entries.isEmpty) {
          errors.add('$fileName: SRT 解析结果为空');
          fail++;
          continue;
        }

        int? durationMs;
        try {
          final tmpPlayer = AudioPlayer();
          await tmpPlayer.setFilePath(mp3File.path);
          durationMs = tmpPlayer.duration?.inMilliseconds;
          await tmpPlayer.dispose();
        catch (_) {
          // 获取时长失败不影响导入
        }

        final dbFile = await _audioFileRepo.create(AudioFile(
          fileName: fileName,
          audioUri: mp3File.path,
          srtUri: srtPath,
          createdAt: DateTime.now(),
          folderId: folderId,
          durationMs: durationMs,
        ));

        await _sentenceRepo.saveAll(parseResult.entries.map((e) => Sentence(
          audioFileId: dbFile.id!,
          index: e.index,
          startTimeMs: e.startTimeMs,
          endTimeMs: e.endTimeMs,
          text: e.text,
        )).toList());

        success++;
      } catch (e) {
        errors.add('${p.basename(mp3File.path)}: $e');
        fail++;
      }
    }

    return BatchImportResult(successCount: success, failCount: fail, errors: errors, skippedCount: skipped);
  }
}
