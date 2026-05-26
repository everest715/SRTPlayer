enum DictSource { local, online }

class WordNote {
  final int? id;
  final int sentenceId;
  final String word;
  final String definition;
  final DictSource source;

  WordNote({
    this.id,
    required this.sentenceId,
    required this.word,
    required this.definition,
    this.source = DictSource.local,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sentenceId': sentenceId,
      'word': word,
      'definition': definition,
      'source': source.name,
    };
  }

  factory WordNote.fromMap(Map<String, dynamic> map) {
    return WordNote(
      id: map['id'] as int?,
      sentenceId: map['sentenceId'] as int,
      word: map['word'] as String,
      definition: map['definition'] as String,
      source: DictSource.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => DictSource.local,
      ),
    );
  }
}
