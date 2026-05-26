import '../../../models/sentence.dart';

enum PlayerPlaybackStatus { idle, playing, paused, looping }

class PlayerState {
  final int audioFileId;
  final List<Sentence> sentences;
  final int currentSentenceIndex;
  final PlayerPlaybackStatus status;
  final double speed;
  final bool looping;
  final int positionMs;

  const PlayerState({
    required this.audioFileId,
    this.sentences = const [],
    this.currentSentenceIndex = 0,
    this.status = PlayerPlaybackStatus.idle,
    this.speed = 1.0,
    this.looping = false,
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
    int? positionMs,
  }) {
    return PlayerState(
      audioFileId: audioFileId,
      sentences: sentences ?? this.sentences,
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      status: status ?? this.status,
      speed: speed ?? this.speed,
      looping: looping ?? this.looping,
      positionMs: positionMs ?? this.positionMs,
    );
  }
}
