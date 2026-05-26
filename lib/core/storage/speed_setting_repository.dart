import 'package:sqflite/sqflite.dart';
import '../../models/speed_setting.dart';
import 'database.dart';

class SpeedSettingRepository {
  Future<Database> _db() => AppDatabase.instance;

  Future<double> getSpeed(int audioFileId) async {
    final db = await _db();
    final maps = await db.query(
      'speed_settings',
      where: 'audioFileId = ?',
      whereArgs: [audioFileId],
    );
    if (maps.isEmpty) return 1.0;
    return SpeedSetting.fromMap(maps.first).speed;
  }

  Future<void> setSpeed(int audioFileId, double speed) async {
    final db = await _db();
    final existing = await db.query(
      'speed_settings',
      where: 'audioFileId = ?',
      whereArgs: [audioFileId],
    );
    if (existing.isNotEmpty) {
      await db.update(
        'speed_settings',
        {'speed': speed},
        where: 'audioFileId = ?',
        whereArgs: [audioFileId],
      );
    } else {
      await db.insert('speed_settings', {
        'audioFileId': audioFileId,
        'speed': speed,
      });
    }
  }
}
