import 'package:sqflite/sqflite.dart';
import '../../models/word_note.dart';
import 'database.dart';

class WordNoteRepository {
  Future<Database> _db() => AppDatabase.instance;

  Future<List<WordNote>> getBySentenceId(int sentenceId) async {
    final db = await _db();
    final maps = await db.query(
      'word_notes',
      where: 'sentenceId = ?',
      whereArgs: [sentenceId],
    );
    return maps.map((m) => WordNote.fromMap(m)).toList();
  }

  Future<WordNote?> getByWord(int sentenceId, String word) async {
    final db = await _db();
    final maps = await db.query(
      'word_notes',
      where: 'sentenceId = ? AND word = ?',
      whereArgs: [sentenceId, word],
    );
    if (maps.isEmpty) return null;
    return WordNote.fromMap(maps.first);
  }

  Future<void> save(WordNote note) async {
    final db = await _db();
    await db.insert('word_notes', note.toMap());
  }

  Future<void> deleteById(int id) async {
    final db = await _db();
    await db.delete('word_notes', where: 'id = ?', whereArgs: [id]);
  }
}
