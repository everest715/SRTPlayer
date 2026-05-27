enum MarkStatus { none, diff, focus, mastered }

class Sentence {
  final int? id;
  final int audioFileId;
  final int index;
  final int startTimeMs;
  final int endTimeMs;
  final String text;
  final MarkStatus markStatus;

  static final _htmlTagRegex = RegExp(r'<[^>]+>');

  Sentence({
    this.id,
    required this.audioFileId,
    required this.index,
    required this.startTimeMs,
    required this.endTimeMs,
    required String text,
    this.markStatus = MarkStatus.none,
  }) : text = text.replaceAll(_htmlTagRegex, '');

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'audioFileId': audioFileId,
      'idx': index,
      'startTimeMs': startTimeMs,
      'endTimeMs': endTimeMs,
      'text': text,
      'markStatus': markStatus.name,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Sentence.fromMap(Map<String, dynamic> map) {
    return Sentence(
      id: map['id'] as int?,
      audioFileId: map['audioFileId'] as int,
      index: map['idx'] as int,
      startTimeMs: map['startTimeMs'] as int,
      endTimeMs: map['endTimeMs'] as int,
      text: map['text'] as String,
      markStatus: MarkStatus.values.firstWhere(
        (e) => e.name == map['markStatus'],
        orElse: () => MarkStatus.none,
      ),
    );
  }

  Sentence copyWith({
    int? id,
    int? audioFileId,
    int? index,
    int? startTimeMs,
    int? endTimeMs,
    String? text,
    MarkStatus? markStatus,
  }) {
    return Sentence(
      id: id ?? this.id,
      audioFileId: audioFileId ?? this.audioFileId,
      index: index ?? this.index,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      text: text ?? this.text,
      markStatus: markStatus ?? this.markStatus,
    );
  }
}
