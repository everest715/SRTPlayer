import 'package:sqflite/sqflite.dart';
import '../../models/folder.dart';
import 'database.dart';

class FolderRepository {
  Future<Database> _db() => AppDatabase.instance;

  Future<List<Folder>> getAll() async {
    final db = await _db();
    final maps = await db.query('folders', orderBy: 'sortOrder ASC, createdAt ASC');
    return maps.map((m) => Folder.fromMap(m)).toList();
  }

  Future<Folder?> getById(int id) async {
    final db = await _db();
    final maps = await db.query('folders', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Folder.fromMap(maps.first);
  }

  Future<Folder> create(Folder folder) async {
    final db = await _db();
    final id = await db.insert('folders', folder.toMap());
    return folder.copyWith(id: id);
  }

  Future<void> update(Folder folder) async {
    final db = await _db();
    await db.update('folders', folder.toMap(), where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db();
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getAudioCount(int folderId) async {
    final db = await _db();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM audio_files WHERE folderId = ?',
      [folderId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
