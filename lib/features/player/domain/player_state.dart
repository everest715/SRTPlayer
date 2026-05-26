import '../../../models/sentence.dart';

enum PlayerPlaybackStatus { idle, playing, paused, looping }

class PlayerState {
  final int audioFileId;
  final List<Sentence> sentences;
  final int currentSentenceIndex;
  final PlayerPlaybackStatus status;
  final double speed;
  final bool looping;
  final bool continuousPlay;
  final int positionMs;

  const PlayerState({
    required this.audioFileId,
    this.sentences = const [],
    this.currentSentenceIndex = 0,
    this.status = PlayerPlaybackStatus.idle,
    this.speed = 1.0,
    this.looping = false,
    this.continuousPlay = true,
    this.positionMs = 0,
  });

  Sentence? get currentSentence {
    if (sentences.isEmpty || currentSentenceIndex >= sentences.length) return null;
    return sentences[currentSentenceIndex];
  }

  PlayerState copyWith({
    List<Sentence>? sentences,
    int? currentSentenceIndex,
    PlayerPlaybackStatus? status,
    double? speed,
    bool? looping,
    bool? continuousPlay,
    int? positionMs,
  }) {
    return PlayerState(
      audioFileId: audioFileId,
      sentences: sentences ?? this.sentences,
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      status: status ?? this.status,
      speed: speed ?? this.speed,
      looping: looping ?? this.looping,
      continuousPlay: continuousPlay ?? this.continuousPlay,
      positionMs: positionMs ?? this.positionMs,
    );
  }
}
