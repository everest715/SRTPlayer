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

class PendingFile {
  final String audioPath;
  final String? srtPath;
  PendingFile(this.audioPath, this.srtPath);
}

class BatchImportService {
  final AudioFileRepository _audioFileRepo;
  final SentenceRepository _sentenceRepo;

  BatchImportService(this._audioFileRepo, this._sentenceRepo);

  Future<BatchImportResult> importFiles(List<PendingFile> pendingFiles) async {
    int success = 0;
    int fail = 0;
    final errors = <String>[];

    for (final pf in pendingFiles) {
      try {
        final fileName = p.basenameWithoutExtension(pf.audioPath);

        String? srtContent;
        if (pf.srtPath != null && File(pf.srtPath!).existsSync()) {
          srtContent = await File(pf.srtPath!).readAsString();
        }

        if (srtContent == null) {
          errors.add('$fileName: 未找到匹配的 SRT 文件');
          fail++;
          continue;
        }

        final parseResult = SrtParser.parseWithErrors(srtContent);
        if (parseResult.entries.isEmpty) {
          errors.add('$fileName: SRT 解析结果为空');
          fail++;
          continue;
        }

        final dbFile = await _audioFileRepo.create(AudioFile(
          fileName: fileName,
          audioUri: pf.audioPath,
          srtUri: pf.srtPath,
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
        errors.add('${p.basename(pf.audioPath)}: $e');
        fail++;
      }
    }

    return BatchImportResult(successCount: success, failCount: fail, errors: errors);
  }
}
