import 'package:sqflite/sqflite.dart';
import '../../models/audio_file.dart';
import 'database.dart';

class AudioFileRepository {
  Future<Database> _db() => AppDatabase.instance;

  Future<List<AudioFile>> getAll() async {
    final db = await _db();
    final maps = await db.query(
      'audio_files',
      orderBy: 'lastPlayedAt DESC, createdAt DESC',
    );
    return maps.map((m) => AudioFile.fromMap(m)).toList();
  }

  Future<AudioFile?> getById(int id) async {
    final db = await _db();
    final maps = await db.query('audio_files', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return AudioFile.fromMap(maps.first);
  }

  Future<AudioFile> create(AudioFile file) async {
    final db = await _db();
    final id = await db.insert('audio_files', file.toMap());
    return file.copyWith(id: id);
  }

  Future<void> update(AudioFile file) async {
    final db = await _db();
    await db.update('audio_files', file.toMap(), where: 'id = ?', whereArgs: [file.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db();
    await db.delete('audio_files', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AudioFile>> getByFolderId(int? folderId) async {
    final db = await _db();
    final maps = folderId == null
        ? await db.query('audio_files', where: 'folderId IS NULL', orderBy: 'lastPlayedAt DESC, createdAt DESC')
        : await db.query('audio_files', where: 'folderId = ?', whereArgs: [folderId], orderBy: 'lastPlayedAt DESC, createdAt DESC');
    return maps.map((m) => AudioFile.fromMap(m)).toList();
  }

  Future<void> updateFolderId(int audioFileId, int? folderId) async {
    final db = await _db();
    await db.update('audio_files', {'folderId': folderId}, where: 'id = ?', whereArgs: [audioFileId]);
  }
}
