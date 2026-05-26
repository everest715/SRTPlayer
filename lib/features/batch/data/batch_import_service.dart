import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/parser/srt_parser.dart';
import '../../../core/storage/audio_file_repository.dart';
import '../../../core/storage/sentence_repository.dart';
import '../../../models/audio_file.dart';
import '../../../models/sentence.dart';

class BatchImportResult {
  final int successCount;
  final int failCount;
  final List<String> errors;

  BatchImportResult({required this.successCount, required this.failCount, required this.errors});
}

class BatchImportService {
  final AudioFileRepository _audioFileRepo;
  final SentenceRepository _sentenceRepo;

  BatchImportService(this._audioFileRepo, this._sentenceRepo);

  Future<BatchImportResult> importFolder(String folderPath) async {
    int success = 0;
    int fail = 0;
    final errors = <String>[];

    final dir = Directory(folderPath);
    if (!dir.existsSync()) {
      return BatchImportResult(successCount: 0, failCount: 0, errors: ['目录不存在']);
    }

    final mp3Files = dir.listSync()
        .where((f) => p.extension(f.path).toLowerCase() == '.mp3')
        .toList();

    for (final mp3File in mp3Files) {
      try {
        final fileName = p.basenameWithoutExtension(mp3File.path);
        final srtPath = p.join(dir.path, '$fileName.srt');

        if (!File(srtPath).existsSync()) {
          errors.add('$fileName: 未找到匹配的 SRT 文件');
          fail++;
          continue;
        }

        final srtContent = await File(srtPath).readAsString();
        final parseResult = SrtParser.parseWithErrors(srtContent);
        if (parseResult.entries.isEmpty) {
          errors.add('$fileName: SRT 解析结果为空');
          fail++;
          continue;
        }

        final dbFile = await _audioFileRepo.create(AudioFile(
          fileName: fileName,
          audioUri: mp3File.path,
          srtUri: srtPath,
          createdAt: DateTime.now(),
        ));

        final sentences = parseResult.entries.map((e) => Sentence(
          audioFileId: dbFile.id!,
          index: e.index,
          startTimeMs: e.startTimeMs,
          endTimeMs: e.endTimeMs,
          text: e.text,
        )).toList();
        await _sentenceRepo.saveAll(sentences);

        success++;
      } catch (e) {
        errors.add('${p.basename(mp3File.path)}: $e');
        fail++;
      }
    }

    return BatchImportResult(successCount: success, failCount: fail, errors: errors);
  }
}
