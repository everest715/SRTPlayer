import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/audio/audio_player_service.dart';
import '../../../providers/app_providers.dart';
import 'player_state.dart';

final playerProvider = AsyncNotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

class PlayerNotifier extends AsyncNotifier<PlayerState> {
  AudioPlayerService? _audioService;
  StreamSubscription? _positionSub;
  StreamSubscription? _playingSub;
  int? _currentEndMs;
  bool _transitioning = false;

  @override
  Future<PlayerState> build() async {
    ref.onDispose(() {
      _positionSub?.cancel();
      _playingSub?.cancel();
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
        continuousPlay: await SharedPreferences.getInstance().then((p) => p.getBool('continuous_play') ?? true),
      );
    });
  }

  void _listenToAudioEvents() {
    _playingSub = _audioService!.playingStream.listen((isPlaying) {
      if (_transitioning) return;
      final current = state.value;
      if (current == null) return;

      if (isPlaying && current.status == PlayerPlaybackStatus.paused) {
        state = AsyncData(current.copyWith(
          status: current.looping ? PlayerPlaybackStatus.looping : PlayerPlaybackStatus.playing,
        ));
      } else if (!isPlaying && (current.status == PlayerPlaybackStatus.playing || current.status == PlayerPlaybackStatus.looping)) {
        state = AsyncData(current.copyWith(status: PlayerPlaybackStatus.paused));
      }
    });

    _positionSub = _audioService!.positionStream.listen((pos) {
      final current = state.value;
      if (current == null || _currentEndMs == null || _transitioning) return;

      if (pos.inMilliseconds >= _currentEndMs! - 50) {
        _currentEndMs = null;
        state = AsyncData(current.copyWith(positionMs: pos.inMilliseconds));
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
    _currentEndMs = null;
    _transitioning = true;

    state = AsyncData(current.copyWith(
      currentSentenceIndex: index,
      status: current.looping ? PlayerPlaybackStatus.looping : PlayerPlaybackStatus.playing,
      positionMs: sentence.startTimeMs,
    ));

    await _audioService!.playSegment(sentence.startTimeMs, sentence.endTimeMs);
    _transitioning = false;
    _currentEndMs = sentence.endTimeMs;

    final afterPlay = state.value;
    if (afterPlay != null && afterPlay.status != PlayerPlaybackStatus.playing && afterPlay.status != PlayerPlaybackStatus.looping) {
      state = AsyncData(afterPlay.copyWith(
        status: afterPlay.looping ? PlayerPlaybackStatus.looping : PlayerPlaybackStatus.playing,
      ));
    }

    _saveProgress();
  }

  Future<void> _onSentenceComplete() async {
    final current = state.value;
    if (current == null) return;

    if (current.looping) {
      await playSentence(current.currentSentenceIndex);
    } else if (current.continuousPlay && current.currentSentenceIndex < current.sentences.length - 1) {
      await playSentence(current.currentSentenceIndex + 1);
    } else {
      await _audioService?.pause();
      state = AsyncData(current.copyWith(status: PlayerPlaybackStatus.idle));
    }
  }

  Future<void> togglePlayPause() async {
    final current = state.value;
    if (current == null) return;

    if (current.status == PlayerPlaybackStatus.playing || current.status == PlayerPlaybackStatus.looping) {
      await _audioService!.pause();
      state = AsyncData(current.copyWith(status: PlayerPlaybackStatus.paused));
    } else if (current.status == PlayerPlaybackStatus.paused) {
      await _audioService!.play();
      state = AsyncData(current.copyWith(
        status: current.looping ? PlayerPlaybackStatus.looping : PlayerPlaybackStatus.playing,
      ));
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
    final newValue = !current.continuousPlay;
    state = AsyncData(current.copyWith(continuousPlay: newValue));
    ref.read(continuousPlayProvider.notifier).set(newValue);
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
