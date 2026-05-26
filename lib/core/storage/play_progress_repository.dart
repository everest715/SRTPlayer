import 'package:sqflite/sqflite.dart';
import '../../models/play_progress.dart';
import 'database.dart';

class PlayProgressRepository {
  Future<Database> _db() => AppDatabase.instance;

  Future<PlayProgress?> getByAudioFileId(int audioFileId) async {
    final db = await _db();
    final maps = await db.query(
      'play_progress',
      where: 'audioFileId = ?',
      whereArgs: [audioFileId],
    );
    if (maps.isEmpty) return null;
    return PlayProgress.fromMap(maps.first);
  }

  Future<void> upsert(int audioFileId, int sentenceIdx, int positionMs) async {
    final db = await _db();
    final existing = await getByAudioFileId(audioFileId);
    if (existing != null) {
      await db.update(
        'play_progress',
        {'sentenceIdx': sentenceIdx, 'positionMs': positionMs},
        where: 'audioFileId = ?',
        whereArgs: [audioFileId],
      );
    } else {
      await db.insert('play_progress', {
        'audioFileId': audioFileId,
        'sentenceIdx': sentenceIdx,
        'positionMs': positionMs,
      });
    }
  }
}
