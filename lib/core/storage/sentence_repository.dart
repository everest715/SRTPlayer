import 'package:sqflite/sqflite.dart';
import '../../models/sentence.dart';
import 'database.dart';

class SentenceRepository {
  Future<Database> _db() => AppDatabase.instance;

  Future<List<Sentence>> getByAudioFileId(int audioFileId) async {
    final db = await _db();
    final maps = await db.query(
      'sentences',
      where: 'audioFileId = ?',
      whereArgs: [audioFileId],
      orderBy: 'idx ASC',
    );
    return maps.map((m) => Sentence.fromMap(m)).toList();
  }

  Future<void> saveAll(List<Sentence> sentences) async {
    final db = await _db();
    final batch = db.batch();
    for (final s in sentences) {
      batch.insert('sentences', s.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteByAudioFileId(int audioFileId) async {
    final db = await _db();
    await db.delete('sentences', where: 'audioFileId = ?', whereArgs: [audioFileId]);
  }

  Future<void> updateMarkStatus(int sentenceId, MarkStatus status) async {
    final db = await _db();
    await db.update(
      'sentences',
      {'markStatus': status.name},
      where: 'id = ?',
      whereArgs: [sentenceId],
    );
  }
}
