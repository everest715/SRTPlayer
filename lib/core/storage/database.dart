import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  static Database? _instance;

  static Future<Database> get instance async {
    if (_instance != null) return _instance!;
    _instance = await _initDb();
    return _instance!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'srt_player.db');

    return openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE folders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            sortOrder INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE audio_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fileName TEXT NOT NULL,
            audioUri TEXT NOT NULL,
            srtUri TEXT,
            createdAt TEXT NOT NULL,
            lastPlayedAt TEXT,
            status TEXT NOT NULL DEFAULT 'normal',
            folderId INTEGER,
            durationMs INTEGER,
            FOREIGN KEY (folderId) REFERENCES folders(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE sentences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            audioFileId INTEGER NOT NULL,
            idx INTEGER NOT NULL,
            startTimeMs INTEGER NOT NULL,
            endTimeMs INTEGER NOT NULL,
            text TEXT NOT NULL,
            markStatus TEXT NOT NULL DEFAULT 'none',
            FOREIGN KEY (audioFileId) REFERENCES audio_files(id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_sentences_audio ON sentences(audioFileId)',
        );
        await db.execute('''
          CREATE TABLE play_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            audioFileId INTEGER NOT NULL UNIQUE,
            sentenceIdx INTEGER NOT NULL,
            positionMs INTEGER NOT NULL,
            FOREIGN KEY (audioFileId) REFERENCES audio_files(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE speed_settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            audioFileId INTEGER NOT NULL UNIQUE,
            speed REAL NOT NULL,
            FOREIGN KEY (audioFileId) REFERENCES audio_files(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE word_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sentenceId INTEGER NOT NULL,
            word TEXT NOT NULL,
            definition TEXT NOT NULL,
            source TEXT NOT NULL DEFAULT 'local',
            FOREIGN KEY (sentenceId) REFERENCES sentences(id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_word_notes_sentence ON word_notes(sentenceId)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Create folders table
          await db.execute('''
            CREATE TABLE folders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              createdAt TEXT NOT NULL,
              sortOrder INTEGER NOT NULL DEFAULT 0
            )
          ''');
          // Rename audio_files to audio_files_old
          await db.execute('ALTER TABLE audio_files RENAME TO audio_files_old');
          // Create new audio_files with folderId column
          await db.execute('''
            CREATE TABLE audio_files (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              fileName TEXT NOT NULL,
              audioUri TEXT NOT NULL,
              srtUri TEXT,
              createdAt TEXT NOT NULL,
              lastPlayedAt TEXT,
              status TEXT NOT NULL DEFAULT 'normal',
              folderId INTEGER,
              durationMs INTEGER,
              FOREIGN KEY (folderId) REFERENCES folders(id) ON DELETE CASCADE
            )
          ''');
          // Copy data from old to new (folderId will be NULL for existing records)
          await db.execute('''
            INSERT INTO audio_files (id, fileName, audioUri, srtUri, createdAt, lastPlayedAt, status)
            SELECT id, fileName, audioUri, srtUri, createdAt, lastPlayedAt, status
            FROM audio_files_old
          ''');
          // Drop the old table
          await db.execute('DROP TABLE audio_files_old');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE audio_files ADD COLUMN durationMs INTEGER');
        }
      },
    );
  }
}
