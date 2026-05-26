import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../core/storage/database.dart';
import '../core/storage/audio_file_repository.dart';
import '../core/storage/sentence_repository.dart';
import '../core/storage/play_progress_repository.dart';
import '../core/storage/speed_setting_repository.dart';
import '../core/storage/word_note_repository.dart';
import '../core/audio/audio_player_service.dart';
import '../models/audio_file.dart';

final databaseProvider = FutureProvider<Database>((ref) => AppDatabase.instance);

final audioFileRepositoryProvider = Provider<AudioFileRepository>((ref) {
  return AudioFileRepository();
});

final sentenceRepositoryProvider = Provider<SentenceRepository>((ref) {
  return SentenceRepository();
});

final playProgressRepositoryProvider = Provider<PlayProgressRepository>((ref) {
  return PlayProgressRepository();
});

final speedSettingRepositoryProvider = Provider<SpeedSettingRepository>((ref) {
  return SpeedSettingRepository();
});

final wordNoteRepositoryProvider = Provider<WordNoteRepository>((ref) {
  return WordNoteRepository();
});

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(() => service.dispose());
  return service;
});

final currentAudioFileProvider = StateProvider<int?>((ref) => null);

final audioFileListProvider = FutureProvider<List<AudioFile>>((ref) {
  final repo = ref.read(audioFileRepositoryProvider);
  return repo.getAll();
});
