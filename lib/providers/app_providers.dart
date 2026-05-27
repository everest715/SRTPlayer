import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../core/storage/database.dart';
import '../core/storage/audio_file_repository.dart';
import '../core/storage/sentence_repository.dart';
import '../core/storage/play_progress_repository.dart';
import '../core/storage/speed_setting_repository.dart';
import '../core/storage/word_note_repository.dart';
import '../core/audio/audio_player_service.dart';
import '../models/audio_file.dart';
import '../core/storage/folder_repository.dart';
import '../models/folder.dart';

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

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepository();
});

final folderListProvider = FutureProvider<List<Folder>>((ref) {
  final repo = ref.read(folderRepositoryProvider);
  return repo.getAll();
});

final folderAudioCountProvider = FutureProvider.family<int, int>((ref, folderId) {
  final repo = ref.read(folderRepositoryProvider);
  return repo.getAudioCount(folderId);
});

final audioCompletedProvider = FutureProvider.family<bool, int>((ref, audioFileId) {
  final repo = ref.read(sentenceRepositoryProvider);
  return repo.isAllCompleted(audioFileId);
});

final audioFileListProvider = FutureProvider<List<AudioFile>>((ref) {
  final repo = ref.read(audioFileRepositoryProvider);
  return repo.getByFolderId(null).then((list) => list..sort((a, b) => a.fileName.compareTo(b.fileName)));
});

final continuousPlayProvider = StateNotifierProvider<ContinuousPlayNotifier, bool>((ref) {
  return ContinuousPlayNotifier();
});

class ContinuousPlayNotifier extends StateNotifier<bool> {
  static const _key = 'continuous_play';

  ContinuousPlayNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
