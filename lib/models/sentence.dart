enum MarkStatus { none, diff, focus, mastered }

class Sentence {
  final int? id;
  final int audioFileId;
  final int index;
  final int startTimeMs;
  final int endTimeMs;
  final String text;
  final MarkStatus markStatus;
  final bool completed;

  static final _htmlTagRegex = RegExp(r'<[^>]+>');

  Sentence({
    this.id,
    required this.audioFileId,
    required this.index,
    required this.startTimeMs,
    required this.endTimeMs,
    required String text,
    this.markStatus = MarkStatus.none,
    this.completed = false,
  }) : text = text.replaceAll(_htmlTagRegex, '');

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'audioFileId': audioFileId,
      'idx': index,
      'startTimeMs': startTimeMs,
      'endTimeMs': endTimeMs,
      'text': text,
      'markStatus': markStatus.name,
      'completed': completed ? 1 : 0,
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
      completed: (map['completed'] as int?) == 1,
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
    bool? completed,
  }) {
    return Sentence(
      id: id ?? this.id,
      audioFileId: audioFileId ?? this.audioFileId,
      index: index ?? this.index,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      text: text ?? this.text,
      markStatus: markStatus ?? this.markStatus,
      completed: completed ?? this.completed,
    );
  }
}
