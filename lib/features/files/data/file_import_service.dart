import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import '../../../core/parser/srt_parser.dart';
import '../../../core/storage/audio_file_repository.dart';
import '../../../core/storage/sentence_repository.dart';
import '../../../models/audio_file.dart';
import '../../../models/sentence.dart';

class FileImportResult {
  final AudioFile? audioFile;
  final List<SrtParseError> errors;
  final String? duplicateName;

  FileImportResult({this.audioFile, this.errors = const [], this.duplicateName});

  bool get isDuplicate => duplicateName != null;
}

class FileImportService {
  final AudioFileRepository _audioFileRepo;
  final SentenceRepository _sentenceRepo;

  FileImportService(this._audioFileRepo, this._sentenceRepo);

  Future<FileImportResult?> importAudioWithSrt() async {
    final audioResult = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (audioResult == null || audioResult.files.isEmpty) return null;

    final audioFile = audioResult.files.first;
    final audioPath = audioFile.path!;
    final fileName = p.basenameWithoutExtension(audioPath);

    // Skip if audio with same name already exists
    final existingFiles = await _audioFileRepo.getAll();
    if (existingFiles.any((f) => f.fileName == fileName)) {
      return FileImportResult(duplicateName: fileName);
    }

    final audioDir = p.dirname(audioPath);
    final srtPath = p.join(audioDir, '$fileName.srt');
    String? srtUri;
    String? srtContent;

    if (File(srtPath).existsSync()) {
      srtUri = srtPath;
      srtContent = await File(srtPath).readAsString();
    }

    if (srtContent == null) {
      final srtResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt'],
        allowMultiple: false,
      );
      if (srtResult != null && srtResult.files.isNotEmpty) {
        srtUri = srtResult.files.first.path!;
        srtContent = await File(srtUri!).readAsString();
      }
    }

    if (srtContent == null) return null;

    final parseResult = SrtParser.parseWithErrors(srtContent);
    if (parseResult.entries.isEmpty && srtContent.trim().isNotEmpty) {
      throw Exception('SRT 解析失败：没有有效的字幕条目');
    }

    int? durationMs;
    try {
      final tmpPlayer = AudioPlayer();
      await tmpPlayer.setFilePath(audioPath);
      durationMs = tmpPlayer.duration?.inMilliseconds;
      await tmpPlayer.dispose();
    } catch (_) {
      // 获取时长失败不影响导入
    }

    final dbAudioFile = AudioFile(
      fileName: fileName,
      audioUri: audioPath,
      srtUri: srtUri,
      durationMs: durationMs,
      createdAt: DateTime.now(),
    );
    final savedFile = await _audioFileRepo.create(dbAudioFile);

    final sentences = parseResult.entries.map((e) => Sentence(
      audioFileId: savedFile.id!,
      index: e.index,
      startTimeMs: e.startTimeMs,
      endTimeMs: e.endTimeMs,
      text: e.text,
    )).toList();
    await _sentenceRepo.saveAll(sentences);

    return FileImportResult(audioFile: savedFile, errors: parseResult.errors);
  }


}
