class PlayProgress {
  final int? id;
  final int audioFileId;
  final int sentenceIdx;
  final int positionMs;

  PlayProgress({
    this.id,
    required this.audioFileId,
    required this.sentenceIdx,
    required this.positionMs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'audioFileId': audioFileId,
      'sentenceIdx': sentenceIdx,
      'positionMs': positionMs,
    };
  }

  factory PlayProgress.fromMap(Map<String, dynamic> map) {
    return PlayProgress(
      id: map['id'] as int?,
      audioFileId: map['audioFileId'] as int,
      sentenceIdx: map['sentenceIdx'] as int,
      positionMs: map['positionMs'] as int,
    );
  }
}
