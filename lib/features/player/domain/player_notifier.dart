import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio/audio_player_service.dart';
import '../../../providers/app_providers.dart';
import 'player_state.dart';

final playerProvider = AsyncNotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

class PlayerNotifier extends AsyncNotifier<PlayerState> {
  AudioPlayerService? _audioService;
  StreamSubscription? _positionSub;
  StreamSubscription? _completeSub;
  int? _currentEndMs;

  @override
  Future<PlayerState> build() async {
    ref.onDispose(() {
      _positionSub?.cancel();
      _completeSub?.cancel();
      _audioService?.dispose();
    });
    return const PlayerState(audioFileId: -1);
  }

  Future<void> loadFile(int audioFileId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final audioRepo = ref.read(audioFileRepositoryProvider);
      final sentenceRepo = ref.read(sentenceRepositoryProvider);
      final speedRepo = ref.read(speedSettingRepositoryProvider);
      final progressRepo = ref.read(playProgressRepositoryProvider);

      final audioFile = await audioRepo.getById(audioFileId);
      if (audioFile == null) throw Exception('音频文件不存在');

      final sentences = await sentenceRepo.getByAudioFileId(audioFileId);
      if (sentences.isEmpty) throw Exception('没有字幕数据');

      final savedSpeed = await speedRepo.getSpeed(audioFileId);
      final progress = await progressRepo.getByAudioFileId(audioFileId);
      final startIdx = progress?.sentenceIdx ?? 0;

      _audioService = ref.read(audioPlayerServiceProvider);
      await _audioService!.setUrl(audioFile.audioUri);
      await _audioService!.setSpeed(savedSpeed);

      _listenToAudioEvents();

      return PlayerState(
        audioFileId: audioFileId,
        sentences: sentences,
        currentSentenceIndex: startIdx,
        speed: savedSpeed,
      );
    });
  }

  void _listenToAudioEvents() {
    _positionSub = _audioService!.positionStream.listen((pos) {
      final current = state.value;
      if (current == null) return;

      if (_currentEndMs != null && pos.inMilliseconds >= _currentEndMs! - 50) {
        // Clamp position to sentence end so progress bar reaches 100%
        state = AsyncData(current.copyWith(positionMs: _currentEndMs!));
        _onSentenceComplete();
        return;
      }

      state = AsyncData(current.copyWith(positionMs: pos.inMilliseconds));
    });
  }

  Future<void> playSentence(int index) async {
    final current = state.value;
    if (current == null || index < 0 || index >= current.sentences.length) return;

    final sentence = current.sentences[index];
    _currentEndMs = sentence.endTimeMs;
    await _audioService!.playSegment(sentence.startTimeMs, sentence.endTimeMs);

    state = AsyncData(current.copyWith(
      currentSentenceIndex: index,
      status: current.looping ? PlayerPlaybackStatus.looping : PlayerPlaybackStatus.playing,
    ));

    _saveProgress();
  }

  void _onSentenceComplete() {
    final current = state.value;
    if (current == null) return;

    if (current.looping) {
      playSentence(current.currentSentenceIndex);
    } else if (current.continuousPlay && current.currentSentenceIndex < current.sentences.length - 1) {
      playSentence(current.currentSentenceIndex + 1);
    } else {
      state = AsyncData(current.copyWith(status: PlayerPlaybackStatus.idle));
    }
  }

  Future<void> togglePlayPause() async {
    final current = state.value;
    if (current == null) return;

    if (current.status == PlayerPlaybackStatus.playing ||
        current.status == PlayerPlaybackStatus.looping) {
      await _audioService!.pause();
      state = AsyncData(current.copyWith(status: PlayerPlaybackStatus.paused));
    } else {
      await playSentence(current.currentSentenceIndex);
    }
  }

  Future<void> nextSentence() async {
    final current = state.value;
    if (current == null) return;
    final next = (current.currentSentenceIndex + 1).clamp(0, current.sentences.length - 1);
    await playSentence(next);
  }

  Future<void> prevSentence() async {
    final current = state.value;
    if (current == null) return;
    final prev = (current.currentSentenceIndex - 1).clamp(0, current.sentences.length - 1);
    await playSentence(prev);
  }

  void toggleLooping() {
    final current = state.value;
    if (current == null) return;
    final newLooping = !current.looping;
    _audioService?.toggleLooping();
    state = AsyncData(current.copyWith(
      looping: newLooping,
      status: newLooping ? PlayerPlaybackStatus.looping : PlayerPlaybackStatus.playing,
    ));
  }

  void toggleContinuousPlay() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(continuousPlay: !current.continuousPlay));
  }

  Future<void> setSpeed(double speed) async {
    final current = state.value;
    if (current == null) return;
    await _audioService!.setSpeed(speed);
    final speedRepo = ref.read(speedSettingRepositoryProvider);
    await speedRepo.setSpeed(current.audioFileId, speed);
    state = AsyncData(current.copyWith(speed: speed));
  }

  Future<void> seekTo(int ms) async {
    await _audioService!.seekTo(ms);
  }

  void _saveProgress() {
    final current = state.value;
    if (current == null) return;
    final progressRepo = ref.read(playProgressRepositoryProvider);
    progressRepo.upsert(
      current.audioFileId,
      current.currentSentenceIndex,
      current.positionMs,
    );
  }
}
