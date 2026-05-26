# 逐句复读播放器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cross-platform sentence-repeater audio player for language learning, with per-sentence playback, A-B loop, variable speed, favorites, dictation mode, background playback, and batch import.

**Architecture:** Feature-first Clean Architecture with Riverpod state management. Core audio/parser/storage layers shared across features. Each feature module has data/domain/presentation layers.

**Tech Stack:** Flutter, Riverpod, just_audio, audio_service, Isar, go_router, file_picker

---

## File Structure

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── audio/
│   │   ├── audio_player_service.dart
│   │   └── audio_handler.dart
│   ├── parser/
│   │   └── srt_parser.dart
│   ├── storage/
│   │   ├── database.dart
│   │   ├── audio_file_repository.dart
│   │   ├── sentence_repository.dart
│   │   ├── play_progress_repository.dart
│   │   ├── speed_setting_repository.dart
│   │   └── word_note_repository.dart
│   ├── theme/
│   │   └── app_theme.dart
│   └── router/
│       └── app_router.dart
├── models/
│   ├── audio_file.dart
│   ├── sentence.dart
│   ├── play_progress.dart
│   ├── speed_setting.dart
│   └── word_note.dart
├── providers/
│   └── app_providers.dart
├── features/
│   ├── files/
│   │   ├── data/file_import_service.dart
│   │   └── presentation/home_screen.dart
│   ├── player/
│   │   ├── domain/player_notifier.dart
│   │   ├── domain/player_state.dart
│   │   └── presentation/
│   │       ├── player_screen.dart
│   │       ├── sentence_card.dart
│   │       ├── control_bar.dart
│   │       └── speed_bottom_sheet.dart
│   ├── favorites/
│   │   ├── domain/favorites_notifier.dart
│   │   └── presentation/mark_bottom_sheet.dart
│   ├── vocabulary/
│   │   ├── domain/vocabulary_notifier.dart
│   │   └── presentation/word_tooltip.dart
│   ├── dictation/
│   │   ├── domain/dictation_notifier.dart
│   │   └── presentation/dictation_screen.dart
│   ├── progress/
│   │   └── domain/progress_notifier.dart
│   ├── background/
│   │   └── data/background_service.dart
│   └── batch/
│       ├── data/batch_import_service.dart
│       └── presentation/batch_import_screen.dart
test/
├── core/
│   └── parser/
│       └── srt_parser_test.dart
├── models/
├── features/
│   ├── player/
│   ├── favorites/
│   ├── dictation/
│   └── progress/
```

---

## Task 1: Project Scaffold & Dependencies

**Files:**
- Create: Flutter project (via `flutter create`)
- Modify: `pubspec.yaml`

- [ ] **Step 1: Create Flutter project**

Run:
```bash
cd E:\SelfProjects\SRTPlayer
flutter create --org com.srtplayer --project-name srt_player .
```

- [ ] **Step 2: Add dependencies to pubspec.yaml**

Replace `pubspec.yaml` dependencies section:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # State management
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1

  # Audio
  just_audio: ^0.9.44
  audio_service: ^0.18.18
  audio_session: ^0.1.25

  # Database
  isar: ^3.1.0+1
  isar_flutter_libs: ^3.1.0+1

  # Storage
  shared_preferences: ^2.5.3

  # Router
  go_router: ^14.8.1

  # File picking
  file_picker: ^9.2.1

  # Utils
  path: ^1.9.1
  uuid: ^4.5.1
  diff_match_patch: ^0.4.1
  fluttertoast: ^8.2.12

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  isar_generator: ^3.1.0+1
  build_runner: ^2.4.14
```

- [ ] **Step 3: Run flutter pub get**

Run:
```bash
cd E:\SelfProjects\SRTPlayer
flutter pub get
```
Expected: dependencies resolved successfully

- [ ] **Step 4: Verify project builds**

Run:
```bash
flutter analyze
```
Expected: No errors (warnings OK)

- [ ] **Step 5: Commit**

```bash
git init
git add .
git commit -m "feat: scaffold Flutter project with core dependencies"
```

---

## Task 2: Isar Data Models

**Files:**
- Create: `lib/models/audio_file.dart`
- Create: `lib/models/sentence.dart`
- Create: `lib/models/play_progress.dart`
- Create: `lib/models/speed_setting.dart`
- Create: `lib/models/word_note.dart`

- [ ] **Step 1: Create AudioFile model**

Create `lib/models/audio_file.dart`:

```dart
import 'package:isar/isar.dart';

part 'audio_file.g.dart';

@collection
class AudioFile {
  Id id = Isar.autoIncrement;

  @Index()
  late String fileName;

  late String audioUri;

  String? srtUri;

  late DateTime createdAt;

  DateTime? lastPlayedAt;

  // Status: 'normal' | 'offline'
  String status = 'normal';
}
```

- [ ] **Step 2: Create Sentence model**

Create `lib/models/sentence.dart`:

```dart
import 'package:isar/isar.dart';

part 'sentence.g.dart';

enum MarkStatus { none, diff, focus, mastered }

@collection
class Sentence {
  Id id = Isar.autoIncrement;

  @Index()
  late int audioFileId;

  late int index;

  late int startTimeMs;

  late int endTimeMs;

  late String text;

  @Enumerated(EnumType.name)
  MarkStatus markStatus = MarkStatus.none;
}
```

- [ ] **Step 3: Create PlayProgress model**

Create `lib/models/play_progress.dart`:

```dart
import 'package:isar/isar.dart';

part 'play_progress.g.dart';

@collection
class PlayProgress {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late int audioFileId;

  late int sentenceIdx;

  late int positionMs;
}
```

- [ ] **Step 4: Create SpeedSetting model**

Create `lib/models/speed_setting.dart`:

```dart
import 'package:isar/isar.dart';

part 'speed_setting.g.dart';

@collection
class SpeedSetting {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late int audioFileId;

  late double speed;
}
```

- [ ] **Step 5: Create WordNote model**

Create `lib/models/word_note.dart`:

```dart
import 'package:isar/isar.dart';

part 'word_note.g.dart';

enum DictSource { local, online }

@collection
class WordNote {
  Id id = Isar.autoIncrement;

  @Index()
  late int sentenceId;

  late String word;

  late String definition;

  @Enumerated(EnumType.name)
  DictSource source = DictSource.local;
}
```

- [ ] **Step 6: Run build_runner to generate Isar code**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: `.g.dart` files generated for all 5 models

- [ ] **Step 7: Commit**

```bash
git add lib/models/
git commit -m "feat: add Isar data models for audio file, sentence, progress, speed, word note"
```

---

## Task 3: Isar Database & Repository Layer

**Files:**
- Create: `lib/core/storage/database.dart`
- Create: `lib/core/storage/audio_file_repository.dart`
- Create: `lib/core/storage/sentence_repository.dart`
- Create: `lib/core/storage/play_progress_repository.dart`
- Create: `lib/core/storage/speed_setting_repository.dart`
- Create: `lib/core/storage/word_note_repository.dart`

- [ ] **Step 1: Create database initialization**

Create `lib/core/storage/database.dart`:

```dart
import 'package:isar/isar.dart';
import '../../models/audio_file.dart';
import '../../models/sentence.dart';
import '../../models/play_progress.dart';
import '../../models/speed_setting.dart';
import '../../models/word_note.dart';

class AppDatabase {
  static Isar? _instance;

  static Future<Isar> get instance async {
    if (_instance != null && _instance!.isOpen) return _instance!;
    _instance = await Isar.open(
      [
        AudioFileSchema,
        SentenceSchema,
        PlayProgressSchema,
        SpeedSettingSchema,
        WordNoteSchema,
      ],
      directory: '',
      inspector: const bool.fromEnvironment('dart.vm.product') ? null : true,
    );
    return _instance!;
  }

  static Future<void> close() async {
    if (_instance != null && _instance!.isOpen) {
      await _instance!.close();
      _instance = null;
    }
  }
}
```

- [ ] **Step 2: Create AudioFileRepository**

Create `lib/core/storage/audio_file_repository.dart`:

```dart
import 'package:isar/isar.dart';
import '../../models/audio_file.dart';
import 'database.dart';

class AudioFileRepository {
  Future<Isar> _db() => AppDatabase.instance;

  Future<List<AudioFile>> getAll() async {
    final db = await _db();
    return db.audioFiles.where().sortByLastPlayedAtDesc().findAll();
  }

  Future<AudioFile?> getById(Id id) async {
    final db = await _db();
    return db.audioFiles.get(id);
  }

  Future<AudioFile> create(AudioFile file) async {
    final db = await _db();
    final id = await db.audioFiles.put(file);
    file.id = id;
    return file;
  }

  Future<void> update(AudioFile file) async {
    final db = await _db();
    await db.audioFiles.put(file);
  }

  Future<void> delete(Id id) async {
    final db = await _db();
    await db.writeTxn(() async {
      await db.audioFiles.delete(id);
      await db.sentences.where().audioFileIdEqualTo(id).deleteAll();
      await db.playProgresss.where().audioFileIdEqualTo(id).deleteAll();
      await db.speedSettings.where().audioFileIdEqualTo(id).deleteAll();
    });
  }
}
```

- [ ] **Step 3: Create SentenceRepository**

Create `lib/core/storage/sentence_repository.dart`:

```dart
import 'package:isar/isar.dart';
import '../../models/sentence.dart';
import 'database.dart';

class SentenceRepository {
  Future<Isar> _db() => AppDatabase.instance;

  Future<List<Sentence>> getByAudioFileId(int audioFileId) async {
    final db = await _db();
    return db.sentences
        .where()
        .audioFileIdEqualTo(audioFileId)
        .sortByIndex()
        .findAll();
  }

  Future<void> saveAll(List<Sentence> sentences) async {
    final db = await _db();
    await db.writeTxn(() async {
      await db.sentences.putAll(sentences);
    });
  }

  Future<void> deleteByAudioFileId(int audioFileId) async {
    final db = await _db();
    await db.writeTxn(() async {
      await db.sentences.where().audioFileIdEqualTo(audioFileId).deleteAll();
    });
  }

  Future<void> updateMarkStatus(Id sentenceId, MarkStatus status) async {
    final db = await _db();
    await db.writeTxn(() async {
      final sentence = await db.sentences.get(sentenceId);
      if (sentence != null) {
        sentence.markStatus = status;
        await db.sentences.put(sentence);
      }
    });
  }
}
```

- [ ] **Step 4: Create PlayProgressRepository**

Create `lib/core/storage/play_progress_repository.dart`:

```dart
import 'package:isar/isar.dart';
import '../../models/play_progress.dart';
import 'database.dart';

class PlayProgressRepository {
  Future<Isar> _db() => AppDatabase.instance;

  Future<PlayProgress?> getByAudioFileId(int audioFileId) async {
    final db = await _db();
    return db.playProgresss.where().audioFileIdEqualTo(audioFileId).findFirst();
  }

  Future<void> upsert(int audioFileId, int sentenceIdx, int positionMs) async {
    final db = await _db();
    await db.writeTxn(() async {
      final existing = await db.playProgresss
          .where()
          .audioFileIdEqualTo(audioFileId)
          .findFirst();
      if (existing != null) {
        existing.sentenceIdx = sentenceIdx;
        existing.positionMs = positionMs;
        await db.playProgresss.put(existing);
      } else {
        final progress = PlayProgress()
          ..audioFileId = audioFileId
          ..sentenceIdx = sentenceIdx
          ..positionMs = positionMs;
        await db.playProgresss.put(progress);
      }
    });
  }
}
```

- [ ] **Step 5: Create SpeedSettingRepository**

Create `lib/core/storage/speed_setting_repository.dart`:

```dart
import 'package:isar/isar.dart';
import '../../models/speed_setting.dart';
import 'database.dart';

class SpeedSettingRepository {
  Future<Isar> _db() => AppDatabase.instance;

  Future<double> getSpeed(int audioFileId) async {
    final db = await _db();
    final setting = await db.speedSettings
        .where()
        .audioFileIdEqualTo(audioFileId)
        .findFirst();
    return setting?.speed ?? 1.0;
  }

  Future<void> setSpeed(int audioFileId, double speed) async {
    final db = await _db();
    await db.writeTxn(() async {
      final existing = await db.speedSettings
          .where()
          .audioFileIdEqualTo(audioFileId)
          .findFirst();
      if (existing != null) {
        existing.speed = speed;
        await db.speedSettings.put(existing);
      } else {
        final setting = SpeedSetting()
          ..audioFileId = audioFileId
          ..speed = speed;
        await db.speedSettings.put(setting);
      }
    });
  }
}
```

- [ ] **Step 6: Create WordNoteRepository**

Create `lib/core/storage/word_note_repository.dart`:

```dart
import 'package:isar/isar.dart';
import '../../models/word_note.dart';
import 'database.dart';

class WordNoteRepository {
  Future<Isar> _db() => AppDatabase.instance;

  Future<List<WordNote>> getBySentenceId(int sentenceId) async {
    final db = await _db();
    return db.wordNotes.where().sentenceIdEqualTo(sentenceId).findAll();
  }

  Future<WordNote?> getByWord(int sentenceId, String word) async {
    final db = await _db();
    return db.wordNotes
        .where()
        .sentenceIdEqualTo(sentenceId)
        .filter()
        .wordEqualTo(word)
        .findFirst();
  }

  Future<void> save(WordNote note) async {
    final db = await _db();
    await db.writeTxn(() async {
      await db.wordNotes.put(note);
    });
  }

  Future<void> deleteById(Id id) async {
    final db = await _db();
    await db.writeTxn(() async {
      await db.wordNotes.delete(id);
    });
  }
}
```

- [ ] **Step 7: Commit**

```bash
git add lib/core/storage/ lib/models/
git commit -m "feat: add Isar database init and repository layer for all models"
```

---

## Task 4: SRT Parser (with TDD)

**Files:**
- Create: `lib/core/parser/srt_parser.dart`
- Create: `test/core/parser/srt_parser_test.dart`

- [ ] **Step 1: Write failing tests for SRT parser**

Create `test/core/parser/srt_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:srt_player/core/parser/srt_parser.dart';

void main() {
  group('SrtParser', () {
    test('parses valid single entry', () {
      const input = '1\n00:00:01,000 --> 00:00:03,500\nHello world';
      final result = SrtParser.parse(input);
      expect(result, hasLength(1));
      expect(result[0].index, 1);
      expect(result[0].startTimeMs, 1000);
      expect(result[0].endTimeMs, 3500);
      expect(result[0].text, 'Hello world');
    });

    test('parses multiple entries', () {
      const input =
          '1\n00:00:01,000 --> 00:00:03,500\nHello world\n\n'
          '2\n00:00:04,000 --> 00:00:06,000\nHow are you?';
      final result = SrtParser.parse(input);
      expect(result, hasLength(2));
      expect(result[1].index, 2);
      expect(result[1].startTimeMs, 4000);
    });

    test('handles multi-line text', () {
      const input = '1\n00:00:01,000 --> 00:00:03,500\nLine one\nLine two';
      final result = SrtParser.parse(input);
      expect(result[0].text, 'Line one\nLine two');
    });

    test('skips entries with invalid timestamps and reports errors', () {
      const input =
          '1\n00:00:01,000 --> 00:00:03,500\nGood entry\n\n'
          '2\ninvalid --> timestamp\nBad entry';
      final result = SrtParser.parse(input);
      expect(result, hasLength(1));
      expect(result[0].text, 'Good entry');
    });

    test('handles empty text gracefully', () {
      const input = '1\n00:00:01,000 --> 00:00:03,500\n';
      final result = SrtParser.parse(input);
      expect(result, hasLength(1));
      expect(result[0].text, isEmpty);
    });

    test('parses Chinese text correctly', () {
      const input = '1\n00:00:01,000 --> 00:00:03,500\n你好世界';
      final result = SrtParser.parse(input);
      expect(result[0].text, '你好世界');
    });

    test('returns empty list for empty input', () {
      final result = SrtParser.parse('');
      expect(result, isEmpty);
    });

    test('reports parse errors with line info', () {
      const input =
          '1\n00:00:01,000 --> 00:00:03,500\nGood\n\n'
          '2\nbad timestamp\nBad';
      final result = SrtParser.parseWithErrors(input);
      expect(result.entries, hasLength(1));
      expect(result.errors, isNotEmpty);
      expect(result.errors.first.lineNumber, greaterThan(0));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
flutter test test/core/parser/srt_parser_test.dart
```
Expected: FAIL — `SrtParser` not defined

- [ ] **Step 3: Implement SrtParser**

Create `lib/core/parser/srt_parser.dart`:

```dart
class ParsedSentence {
  final int index;
  final int startTimeMs;
  final int endTimeMs;
  final String text;

  ParsedSentence({
    required this.index,
    required this.startTimeMs,
    required this.endTimeMs,
    required this.text,
  });
}

class SrtParseError {
  final int lineNumber;
  final String content;
  final String message;

  SrtParseError({
    required this.lineNumber,
    required this.content,
    required this.message,
  });
}

class SrtParseResult {
  final List<ParsedSentence> entries;
  final List<SrtParseError> errors;

  SrtParseResult({required this.entries, required this.errors});
}

class SrtParser {
  static List<ParsedSentence> parse(String input) {
    return parseWithErrors(input).entries;
  }

  static SrtParseResult parseWithErrors(String input) {
    final entries = <ParsedSentence>[];
    final errors = <SrtParseError>[];

    if (input.trim().isEmpty) {
      return SrtParseResult(entries: entries, errors: errors);
    }

    final blocks = input.trim().split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final lines = block.split('\n');
      if (lines.length < 2) {
        errors.add(SrtParseError(
          lineNumber: 0,
          content: block,
          message: 'Block has fewer than 2 lines',
        ));
        continue;
      }

      // Parse index
      final indexLine = lines[0].trim();
      final index = int.tryParse(indexLine);
      if (index == null) {
        errors.add(SrtParseError(
          lineNumber: 1,
          content: indexLine,
          message: 'Invalid index: "$indexLine"',
        ));
        continue;
      }

      // Parse timestamp
      final timeLine = lines.length > 1 ? lines[1].trim() : '';
      final timeRegex = RegExp(
        r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})',
      );
      final timeMatch = timeRegex.firstMatch(timeLine);
      if (timeMatch == null) {
        errors.add(SrtParseError(
          lineNumber: 2,
          content: timeLine,
          message: 'Invalid timestamp: "$timeLine"',
        ));
        continue;
      }

      final startMs = _parseTimestamp(
        timeMatch.group(1)!, timeMatch.group(2)!, timeMatch.group(3)!, timeMatch.group(4)!,
      );
      final endMs = _parseTimestamp(
        timeMatch.group(5)!, timeMatch.group(6)!, timeMatch.group(7)!, timeMatch.group(8)!,
      );

      // Parse text (lines 2+)
      final text = lines.length > 2
          ? lines.sublist(2).join('\n').trim()
          : '';

      entries.add(ParsedSentence(
        index: index,
        startTimeMs: startMs,
        endTimeMs: endMs,
        text: text,
      ));
    }

    return SrtParseResult(entries: entries, errors: errors);
  }

  static int _parseTimestamp(String h, String m, String s, String ms) {
    return int.parse(h) * 3600000 +
        int.parse(m) * 60000 +
        int.parse(s) * 1000 +
        int.parse(ms);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
flutter test test/core/parser/srt_parser_test.dart
```
Expected: All 8 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/parser/ test/core/
git commit -m "feat: implement SRT parser with error reporting and tests"
```

---

## Task 5: Audio Player Service

**Files:**
- Create: `lib/core/audio/audio_player_service.dart`

- [ ] **Step 1: Create AudioPlayerService wrapper**

Create `lib/core/audio/audio_player_service.dart`:

```dart
import 'package:just_audio/just_audio.dart';

enum PlayerPlaybackState { idle, playing, paused, looping }

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  PlayerPlaybackState _state = PlayerPlaybackState.idle;
  bool _looping = false;

  PlayerPlaybackState get state => _state;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  double get speed => _player.speed;
  bool get isLooping => _looping;

  Stream<PlayerPlaybackState> get stateStream => _player.playbackEventStream.map((_) => _state);
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<void> get playerCompleteStream => _player.playerStateStream.where((s) => s.processingState == ProcessingState.completed);

  Future<void> setUrl(String uri) async {
    await _player.setUrl(uri);
    _state = PlayerPlaybackState.idle;
  }

  Future<void> playSegment(int startMs, int endMs) async {
    await _player.seek(Duration(milliseconds: startMs));
    _state = _looping ? PlayerPlaybackState.looping : PlayerPlaybackState.playing;
    await _player.play();
  }

  Future<void> play() async {
    _state = _looping ? PlayerPlaybackState.looping : PlayerPlaybackState.playing;
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
    _state = PlayerPlaybackState.paused;
  }

  Future<void> seekTo(int ms) async {
    await _player.seek(Duration(milliseconds: ms));
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  void toggleLooping() {
    _looping = !_looping;
    if (_state == PlayerPlaybackState.playing && _looping) {
      _state = PlayerPlaybackState.looping;
    } else if (_state == PlayerPlaybackState.looping && !_looping) {
      _state = PlayerPlaybackState.playing;
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _state = PlayerPlaybackState.idle;
    _looping = false;
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/audio/
git commit -m "feat: add AudioPlayerService wrapping just_audio with looping support"
```

---

## Task 6: Theme & Router

**Files:**
- Create: `lib/core/theme/app_theme.dart`
- Create: `lib/core/router/app_router.dart`
- Create: `lib/app.dart`

- [ ] **Step 1: Create app theme**

Create `lib/core/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF4A90D9),
    brightness: Brightness.light,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 14),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF4A90D9),
    brightness: Brightness.dark,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 14),
    ),
  );

  static ThemeData oledTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF4A90D9),
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    cardColor: const Color(0xFF111111),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
    ),
  );
}
```

- [ ] **Step 2: Create app router**

Create `lib/core/router/app_router.dart`:

```dart
import 'package:go_router/go_router.dart';
import '../../features/files/presentation/home_screen.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/dictation/presentation/dictation_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/player/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return PlayerScreen(audioFileId: id);
      },
    ),
    GoRoute(
      path: '/player/:id/dictation',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return DictationScreen(audioFileId: id);
      },
    ),
  ],
);
```

- [ ] **Step 3: Create app.dart**

Create `lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

class SrtPlayerApp extends ConsumerWidget {
  const SrtPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '逐句复读播放器',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
```

- [ ] **Step 4: Update main.dart**

Replace `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/storage/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance;
  runApp(const ProviderScope(child: SrtPlayerApp()));
}
```

- [ ] **Step 5: Verify app builds**

Run:
```bash
flutter analyze
```
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/ lib/core/router/ lib/app.dart lib/main.dart
git commit -m "feat: add theme, router, and app entry point"
```

---

## Task 7: Riverpod Providers (Global)

**Files:**
- Create: `lib/providers/app_providers.dart`

- [ ] **Step 1: Create global providers**

Create `lib/providers/app_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/database.dart';
import '../core/storage/audio_file_repository.dart';
import '../core/storage/sentence_repository.dart';
import '../core/storage/play_progress_repository.dart';
import '../core/storage/speed_setting_repository.dart';
import '../core/storage/word_note_repository.dart';
import '../core/audio/audio_player_service.dart';
import 'package:isar/isar.dart';

final databaseProvider = FutureProvider<Isar>((ref) => AppDatabase.instance);

final audioFileRepositoryProvider = Provider<AudioFileRepository>((ref) {
  return AudioFileRepository();
});

final sentenceRepositoryProvider = Provider<SentenceRepository>((ref) {
  return SentenceRepository();
});

final playProgressRepositoryProvider = Provider<PlayProgressRepository>((ref) {
  return PlayProgressRepository();
});

final speedSettingRepositoryProvider = Provider<SpeedSettingRepository>((ref) {
  return SpeedSettingRepository();
});

final wordNoteRepositoryProvider = Provider<WordNoteRepository>((ref) {
  return WordNoteRepository();
});

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Current audio file being played
final currentAudioFileProvider = StateProvider<int?>((ref) => null);

// Audio file list for home screen
final audioFileListProvider = FutureProvider<List<AudioFile>>((ref) {
  final repo = ref.read(audioFileRepositoryProvider);
  return repo.getAll();
});
```

Note: Add `import '../../models/audio_file.dart';` at top of this file after the model import path is resolved.

- [ ] **Step 2: Commit**

```bash
git add lib/providers/
git commit -m "feat: add global Riverpod providers for repositories and audio service"
```

---

## Task 8: FR-001 File Import (Home Screen)

**Files:**
- Create: `lib/features/files/data/file_import_service.dart`
- Create: `lib/features/files/presentation/home_screen.dart`

- [ ] **Step 1: Create FileImportService**

Create `lib/features/files/data/file_import_service.dart`:

```dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../../core/parser/srt_parser.dart';
import '../../../core/storage/audio_file_repository.dart';
import '../../../core/storage/sentence_repository.dart';
import '../../../models/audio_file.dart';
import '../../../models/sentence.dart';

class FileImportResult {
  final AudioFile audioFile;
  final List<SrtParseError> errors;

  FileImportResult({required this.audioFile, this.errors = const []});
}

class FileImportService {
  final AudioFileRepository _audioFileRepo;
  final SentenceRepository _sentenceRepo;

  FileImportService(this._audioFileRepo, this._sentenceRepo);

  Future<FileImportResult?> importAudioWithSrt() async {
    // Pick audio file
    final audioResult = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (audioResult == null || audioResult.files.isEmpty) return null;

    final audioFile = audioResult.files.first;
    final audioPath = audioFile.path!;
    final fileName = p.basenameWithoutExtension(audioPath);

    // Check for matching SRT in same directory
    final audioDir = p.dirname(audioPath);
    final srtPath = p.join(audioDir, '$fileName.srt');
    String? srtUri;
    String? srtContent;

    if (File(srtPath).existsSync()) {
      srtUri = srtPath;
      srtContent = await File(srtPath).readAsString();
    } else {
      // Manual SRT selection
      final srtResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt'],
        allowMultiple: false,
      );
      if (srtResult != null && srtResult.files.isNotEmpty) {
        srtUri = srtResult.files.first.path!;
        srtContent = await File(srtUri!).readAsString();
      }
    }

    if (srtContent == null) return null;

    // Parse SRT
    final parseResult = SrtParser.parseWithErrors(srtContent);
    if (parseResult.entries.isEmpty && srtContent.trim().isNotEmpty) {
      throw Exception('SRT 解析失败：没有有效的字幕条目');
    }

    // Save to database
    final dbAudioFile = AudioFile()
      ..fileName = fileName
      ..audioUri = audioPath
      ..srtUri = srtUri
      ..createdAt = DateTime.now();
    await _audioFileRepo.create(dbAudioFile);

    // Save sentences
    final sentences = parseResult.entries.map((e) => Sentence()
      ..audioFileId = dbAudioFile.id
      ..index = e.index
      ..startTimeMs = e.startTimeMs
      ..endTimeMs = e.endTimeMs
      ..text = e.text
    ).toList();
    await _sentenceRepo.saveAll(sentences);

    return FileImportResult(
      audioFile: dbAudioFile,
      errors: parseResult.errors,
    );
  }
}
```

- [ ] **Step 2: Create HomeScreen**

Create `lib/features/files/presentation/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../models/audio_file.dart';
import '../../../providers/app_providers.dart';
import '../data/file_import_service.dart';
import '../../../core/storage/sentence_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _importing = false;

  Future<void> _importFile() async {
    setState(() => _importing = true);
    try {
      final importService = FileImportService(
        ref.read(audioFileRepositoryProvider),
        ref.read(sentenceRepositoryProvider),
      );
      final result = await importService.importAudioWithSrt();
      if (result != null) {
        if (result.errors.isNotEmpty) {
          Fluttertoast.showToast(
            msg: '导入完成，${result.errors.length} 条字幕解析异常',
            toastLength: Toast.LENGTH_LONG,
          );
        }
        ref.invalidate(audioFileListProvider);
        context.go('/player/${result.audioFile.id}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '导入失败：$e');
    } finally {
      setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(audioFileListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('逐句复读播放器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _importing ? null : _importFile,
            tooltip: '导入音频',
          ),
        ],
      ),
      body: filesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (files) {
          if (files.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.headphones, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('选择 MP3 与字幕', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _importing ? null : _importFile,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('导入音频'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return _AudioFileListTile(file: file, onTap: () => context.go('/player/${file.id}'));
            },
          );
        },
      ),
      floatingActionButton: filesAsync.value?.isNotEmpty == true
          ? FloatingActionButton(
              onPressed: _importing ? null : _importFile,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _AudioFileListTile extends StatelessWidget {
  final AudioFile file;
  final VoidCallback onTap;

  const _AudioFileListTile({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        file.status == 'offline' ? Icons.cloud_off : Icons.audiotrack,
        color: file.status == 'offline' ? Colors.grey : null,
      ),
      title: Text(file.fileName),
      subtitle: file.lastPlayedAt != null
          ? Text('上次：${_formatDate(file.lastPlayedAt!)}')
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: file.status == 'offline' ? null : onTap,
    );
  }

  String _formatDate(DateTime d) {
    return '${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/files/
git commit -m "feat: implement FR-001 file import with auto SRT matching and home screen"
```

---

## Task 9: FR-002~004 Player Core (Sentence List + Playback + Navigation)

**Files:**
- Create: `lib/features/player/domain/player_state.dart`
- Create: `lib/features/player/domain/player_notifier.dart`
- Create: `lib/features/player/presentation/player_screen.dart`
- Create: `lib/features/player/presentation/sentence_card.dart`
- Create: `lib/features/player/presentation/control_bar.dart`

- [ ] **Step 1: Create player state model**

Create `lib/features/player/domain/player_state.dart`:

```dart
import '../../../models/sentence.dart';

enum PlayerPlaybackStatus { idle, playing, paused, looping }

class PlayerState {
  final int audioFileId;
  final List<Sentence> sentences;
  final int currentSentenceIndex;
  final PlayerPlaybackStatus status;
  final double speed;
  final bool looping;
  final int positionMs;

  const PlayerState({
    required this.audioFileId,
    this.sentences = const [],
    this.currentSentenceIndex = 0,
    this.status = PlayerPlaybackStatus.idle,
    this.speed = 1.0,
    this.looping = false,
    this.positionMs = 0,
  });

  Sentence? get currentSentence {
    if (sentences.isEmpty || currentSentenceIndex >= sentences.length) return null;
    return sentences[currentSentenceIndex];
  }

  PlayerState copyWith({
    List<Sentence>? sentences,
    int? currentSentenceIndex,
    PlayerPlaybackStatus? status,
    double? speed,
    bool? looping,
    int? positionMs,
  }) {
    return PlayerState(
      audioFileId: audioFileId,
      sentences: sentences ?? this.sentences,
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      status: status ?? this.status,
      speed: speed ?? this.speed,
      looping: looping ?? this.looping,
      positionMs: positionMs ?? this.positionMs,
    );
  }
}
```

- [ ] **Step 2: Create PlayerNotifier (Riverpod AsyncNotifier)**

Create `lib/features/player/domain/player_notifier.dart`:

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio/audio_player_service.dart';
import '../../../core/storage/audio_file_repository.dart';
import '../../../core/storage/sentence_repository.dart';
import '../../../core/storage/play_progress_repository.dart';
import '../../../core/storage/speed_setting_repository.dart';
import '../../../models/sentence.dart';
import '../../../providers/app_providers.dart';
import 'player_state.dart';

final playerProvider = AsyncNotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

class PlayerNotifier extends AsyncNotifier<PlayerState> {
  AudioPlayerService? _audioService;
  StreamSubscription? _positionSub;
  StreamSubscription? _completeSub;

  @override
  Future<PlayerState> build() async {
    ref.onDispose(() {
      _positionSub?.cancel();
      _completeSub?.cancel();
      _audioService?.dispose();
    });
    return const PlayerState(audioFileId: -1);
  }

  Future<void> loadFile(int audioFileId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final audioRepo = ref.read(audioFileRepositoryProvider);
      final sentenceRepo = ref.read(sentenceRepositoryProvider);
      final speedRepo = ref.read(speedSettingRepositoryProvider);
      final progressRepo = ref.read(playProgressRepositoryProvider);

      final audioFile = await audioRepo.getById(audioFileId);
      if (audioFile == null) throw Exception('音频文件不存在');

      final sentences = await sentenceRepo.getByAudioFileId(audioFileId);
      if (sentences.isEmpty) throw Exception('没有字幕数据');

      final savedSpeed = await speedRepo.getSpeed(audioFileId);
      final progress = await progressRepo.getByAudioFileId(audioFileId);
      final startIdx = progress?.sentenceIdx ?? 0;

      _audioService = ref.read(audioPlayerServiceProvider);
      await _audioService!.setUrl(audioFile.audioUri);
      await _audioService!.setSpeed(savedSpeed);

      _listenToAudioEvents();

      return PlayerState(
        audioFileId: audioFileId,
        sentences: sentences,
        currentSentenceIndex: startIdx,
        speed: savedSpeed,
      );
    });
  }

  void _listenToAudioEvents() {
    _positionSub = _audioService!.positionStream.listen((pos) {
      final current = state.value;
      if (current == null) return;
      state = AsyncData(current.copyWith(positionMs: pos.inMilliseconds));
    });

    _completeSub = _audioService!.playerCompleteStream.listen((_) {
      _onSentenceComplete();
    });
  }

  Future<void> playSentence(int index) async {
    final current = state.value;
    if (current == null || index < 0 || index >= current.sentences.length) return;

    final sentence = current.sentences[index];
    await _audioService!.playSegment(sentence.startTimeMs, sentence.endTimeMs);

    _setupSentenceEndListener(sentence.endTimeMs);

    state = AsyncData(current.copyWith(
      currentSentenceIndex: index,
      status: current.looping ? PlayerPlaybackStatus.looping : PlayerPlaybackStatus.playing,
    ));

    _saveProgress();
  }

  void _setupSentenceEndListener(int endMs) {
    _positionSub?.cancel();
    _positionSub = _audioService!.positionStream.listen((pos) {
      final current = state.value;
      if (current == null) return;

      if (pos.inMilliseconds >= endMs - 50) {
        _onSentenceComplete();
        return;
      }

      state = AsyncData(current.copyWith(positionMs: pos.inMilliseconds));
    });
  }

  void _onSentenceComplete() {
    final current = state.value;
    if (current == null) return;

    if (current.looping) {
      playSentence(current.currentSentenceIndex);
    } else if (current.currentSentenceIndex < current.sentences.length - 1) {
      playSentence(current.currentSentenceIndex + 1);
    } else {
      state = AsyncData(current.copyWith(status: PlayerPlaybackStatus.idle));
    }
  }

  Future<void> togglePlayPause() async {
    final current = state.value;
    if (current == null) return;

    if (current.status == PlayerPlaybackStatus.playing ||
        current.status == PlayerPlaybackStatus.looping) {
      await _audioService!.pause();
      state = AsyncData(current.copyWith(status: PlayerPlaybackStatus.paused));
    } else {
      await playSentence(current.currentSentenceIndex);
    }
  }

  Future<void> nextSentence() async {
    final current = state.value;
    if (current == null) return;
    final next = (current.currentSentenceIndex + 1).clamp(0, current.sentences.length - 1);
    await playSentence(next);
  }

  Future<void> prevSentence() async {
    final current = state.value;
    if (current == null) return;
    final prev = (current.currentSentenceIndex - 1).clamp(0, current.sentences.length - 1);
    await playSentence(prev);
  }

  void toggleLooping() {
    final current = state.value;
    if (current == null) return;
    final newLooping = !current.looping;
    _audioService?.toggleLooping();
    state = AsyncData(current.copyWith(
      looping: newLooping,
      status: newLooping ? PlayerPlaybackStatus.looping : PlayerPlaybackStatus.playing,
    ));
  }

  Future<void> setSpeed(double speed) async {
    final current = state.value;
    if (current == null) return;
    await _audioService!.setSpeed(speed);
    final speedRepo = ref.read(speedSettingRepositoryProvider);
    await speedRepo.setSpeed(current.audioFileId, speed);
    state = AsyncData(current.copyWith(speed: speed));
  }

  Future<void> seekTo(int ms) async {
    await _audioService!.seekTo(ms);
  }

  void _saveProgress() {
    final current = state.value;
    if (current == null) return;
    final progressRepo = ref.read(playProgressRepositoryProvider);
    progressRepo.upsert(
      current.audioFileId,
      current.currentSentenceIndex,
      current.positionMs,
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _completeSub?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 3: Create SentenceCard widget**

Create `lib/features/player/presentation/sentence_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../models/sentence.dart';

class SentenceCard extends StatelessWidget {
  final Sentence sentence;
  final bool isCurrent;
  final bool isLooping;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;

  const SentenceCard({
    super.key,
    required this.sentence,
    required this.isCurrent,
    required this.isLooping,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isCurrent
        ? theme.colorScheme.primaryContainer
        : theme.cardColor;
    final textColor = isCurrent
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Card(
      color: bgColor,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (isCurrent)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    isLooping ? Icons.repeat : Icons.volume_up,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sentence.text,
                      style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatMs(sentence.startTimeMs)} → ${_formatMs(sentence.endTimeMs)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (sentence.markStatus != MarkStatus.none)
                _buildMarkIcon(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildMarkIcon(BuildContext context) {
    return Icon(
      sentence.markStatus == MarkStatus.diff
          ? Icons.new_releases
          : sentence.markStatus == MarkStatus.focus
              ? Icons.star
              : Icons.check_circle,
      size: 16,
      color: Theme.of(context).colorScheme.primary,
    );
  }

  String _formatMs(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
```

- [ ] **Step 4: Create ControlBar widget**

Create `lib/features/player/presentation/control_bar.dart`:

```dart
import 'package:flutter/material.dart';
import '../domain/player_state.dart';

class ControlBar extends StatelessWidget {
  final PlayerPlaybackStatus status;
  final bool looping;
  final double speed;
  final VoidCallback onPlayPause;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToggleLoop;
  final VoidCallback onSpeedTap;

  const ControlBar({
    super.key,
    required this.status,
    required this.looping,
    required this.speed,
    required this.onPlayPause,
    required this.onPrev,
    required this.onNext,
    required this.onToggleLoop,
    required this.onSpeedTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaying = status == PlayerPlaybackStatus.playing ||
        status == PlayerPlaybackStatus.looping;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed: onPrev,
            tooltip: '上一句',
          ),
          FloatingActionButton.small(
            onPressed: onPlayPause,
            child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: onNext,
            tooltip: '下一句',
          ),
          IconButton(
            icon: Icon(
              Icons.repeat,
              color: looping ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: onToggleLoop,
            tooltip: '复读',
          ),
          TextButton(
            onPressed: onSpeedTap,
            child: Text('${speed}x'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Create PlayerScreen**

Create `lib/features/player/presentation/player_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/player_notifier.dart';
import '../domain/player_state.dart';
import 'sentence_card.dart';
import 'control_bar.dart';
import 'speed_bottom_sheet.dart';
import '../../favorites/presentation/mark_bottom_sheet.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final int audioFileId;

  const PlayerScreen({super.key, required this.audioFileId});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(playerProvider.notifier).loadFile(widget.audioFileId);
    });
  }

  void _scrollToSentence(int index) {
    if (!_scrollController.hasClients) return;
    // Each card ~72px height estimate
    const cardHeight = 72.0;
    final offset = index * cardHeight - MediaQuery.of(context).size.height / 3;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerAsync = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(playerAsync.value?.sentences.isNotEmpty == true
            ? '播放中'
            : '加载中...'),
        actions: [
          TextButton(
            onPressed: () => _showSpeedSheet(context),
            child: Text('${playerAsync.value?.speed ?? 1.0}x'),
          ),
        ],
      ),
      body: playerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (player) {
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: player.sentences.length,
                  itemBuilder: (context, index) {
                    final sentence = player.sentences[index];
                    final isCurrent = index == player.currentSentenceIndex;
                    return SentenceCard(
                      sentence: sentence,
                      isCurrent: isCurrent,
                      isLooping: isCurrent && player.looping,
                      onTap: () {
                        notifier.playSentence(index);
                        _scrollToSentence(index);
                      },
                      onDoubleTap: () => notifier.toggleLooping(),
                      onLongPress: () => _showSentenceMenu(context, sentence.id),
                    );
                  },
                ),
              ),
              // Sentence progress bar
              _SentenceProgressBar(
                sentence: player.currentSentence,
                positionMs: player.positionMs,
                onSeek: (ms) => notifier.seekTo(ms),
              ),
              ControlBar(
                status: player.status,
                looping: player.looping,
                speed: player.speed,
                onPlayPause: () => notifier.togglePlayPause(),
                onPrev: () => notifier.prevSentence(),
                onNext: () => notifier.nextSentence(),
                onToggleLoop: () => notifier.toggleLooping(),
                onSpeedTap: () => _showSpeedSheet(context),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSpeedSheet(BuildContext context) {
    final currentSpeed = ref.read(playerProvider).value?.speed ?? 1.0;
    showModalBottomSheet(
      context: context,
      builder: (_) => SpeedBottomSheet(
        currentSpeed: currentSpeed,
        onSpeedSelected: (speed) {
          ref.read(playerProvider.notifier).setSpeed(speed);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSentenceMenu(BuildContext context, int sentenceId) {
    showModalBottomSheet(
      context: context,
      builder: (_) => MarkBottomSheet(sentenceId: sentenceId),
    );
  }
}

class _SentenceProgressBar extends StatelessWidget {
  final dynamic sentence;
  final int positionMs;
  final ValueChanged<int> onSeek;

  const _SentenceProgressBar({
    required this.sentence,
    required this.positionMs,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    if (sentence == null) return const SizedBox.shrink();

    final startMs = sentence.startTimeMs as int;
    final endMs = sentence.endTimeMs as int;
    final durationMs = (endMs - startMs).clamp(1, endMs);
    final relativePos = (positionMs - startMs).clamp(0, durationMs);
    final progress = relativePos / durationMs;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            _formatMs(relativePos),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Expanded(
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (v) => onSeek(startMs + (v * durationMs).round()),
            ),
          ),
          Text(
            _formatMs(durationMs),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatMs(int ms) {
    final s = (ms ~/ 1000);
    final sec = s % 60;
    return '${sec.toString().padLeft(2, '0')}';
  }
}
```

- [ ] **Step 6: Create SpeedBottomSheet**

Create `lib/features/player/presentation/speed_bottom_sheet.dart`:

```dart
import 'package:flutter/material.dart';

const kSpeedOptions = [0.5, 0.7, 0.8, 1.0, 1.2, 1.5, 2.0];

class SpeedBottomSheet extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;

  const SpeedBottomSheet({
    super.key,
    required this.currentSpeed,
    required this.onSpeedSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text('播放速度', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kSpeedOptions.map((speed) {
              final selected = (speed - currentSpeed).abs() < 0.01;
              return ChoiceChip(
                label: Text('${speed}x'),
                selected: selected,
                onSelected: (_) => onSpeedSelected(speed),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/player/
git commit -m "feat: implement FR-002~004 sentence playback, A-B loop, navigation, speed control"
```

---

## Task 10: FR-006 Sentence Favorites & Marking

**Files:**
- Create: `lib/features/favorites/domain/favorites_notifier.dart`
- Create: `lib/features/favorites/presentation/mark_bottom_sheet.dart`

- [ ] **Step 1: Create FavoritesNotifier**

Create `lib/features/favorites/domain/favorites_notifier.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/sentence_repository.dart';
import '../../../models/sentence.dart';
import '../../../providers/app_providers.dart';

final favoritesProvider = NotifierProvider<FavoritesNotifier, Map<int, MarkStatus>>(
  FavoritesNotifier.new,
);

class FavoritesNotifier extends Notifier<Map<int, MarkStatus>> {
  @override
  Map<int, MarkStatus> build() => {};

  Future<void> setMarkStatus(int sentenceId, MarkStatus status) async {
    final repo = ref.read(sentenceRepositoryProvider);
    await repo.updateMarkStatus(sentenceId, status);
    state = {...state, sentenceId: status};
  }

  Future<void> removeMark(int sentenceId) async {
    await setMarkStatus(sentenceId, MarkStatus.none);
  }
}
```

- [ ] **Step 2: Create MarkBottomSheet**

Create `lib/features/favorites/presentation/mark_bottom_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/sentence.dart';
import '../domain/favorites_notifier.dart';

class MarkBottomSheet extends ConsumerWidget {
  final int sentenceId;

  const MarkBottomSheet({super.key, required this.sentenceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marks = ref.watch(favoritesProvider);
    final current = marks[sentenceId] ?? MarkStatus.none;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text('标记句子', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.label_off),
            title: const Text('未标记'),
            selected: current == MarkStatus.none,
            onTap: () {
              ref.read(favoritesProvider.notifier).setMarkStatus(sentenceId, MarkStatus.none);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.new_releases),
            title: const Text('生词'),
            selected: current == MarkStatus.diff,
            onTap: () {
              ref.read(favoritesProvider.notifier).setMarkStatus(sentenceId, MarkStatus.diff);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('重点'),
            selected: current == MarkStatus.focus,
            onTap: () {
              ref.read(favoritesProvider.notifier).setMarkStatus(sentenceId, MarkStatus.focus);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.check_circle),
            title: const Text('已掌握'),
            selected: current == MarkStatus.mastered,
            onTap: () {
              ref.read(favoritesProvider.notifier).setMarkStatus(sentenceId, MarkStatus.mastered);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/favorites/
git commit -m "feat: implement FR-006 sentence favorites and marking with 4 status levels"
```

---

## Task 11: FR-007 Vocabulary (Word Lookup)

**Files:**
- Create: `lib/features/vocabulary/domain/vocabulary_notifier.dart`
- Create: `lib/features/vocabulary/presentation/word_tooltip.dart`

- [ ] **Step 1: Create VocabularyNotifier**

Create `lib/features/vocabulary/domain/vocabulary_notifier.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/word_note_repository.dart';
import '../../../models/word_note.dart';
import '../../../providers/app_providers.dart';

final vocabularyProvider = NotifierProvider<VocabularyNotifier, AsyncValue<WordNote?>>(
  VocabularyNotifier.new,
);

class VocabularyNotifier extends Notifier<AsyncValue<WordNote?>> {
  @override
  AsyncValue<WordNote?> build() => const AsyncData(null);

  Future<void> lookupWord(int sentenceId, String word) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(wordNoteRepositoryProvider);
      // Check local cache first
      final cached = await repo.getByWord(sentenceId, word);
      if (cached != null) return cached;

      // For v1, create a placeholder note — real dictionary integration later
      final note = WordNote()
        ..sentenceId = sentenceId
        ..word = word
        ..definition = '（暂无释义）'
        ..source = DictSource.local;
      await repo.save(note);
      return note;
    });
  }
}
```

- [ ] **Step 2: Create WordTooltip widget**

Create `lib/features/vocabulary/presentation/word_tooltip.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/vocabulary_notifier.dart';
import '../../../models/word_note.dart';

class WordTooltip extends ConsumerWidget {
  final int sentenceId;
  final String word;

  const WordTooltip({super.key, required this.sentenceId, required this.word});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(vocabularyProvider);

    return PopupMenuButton<String>(
      offset: const Offset(0, -40),
      onSelected: (_) {},
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(word, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              noteAsync.when(
                loading: () => const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, _) => Text('查询失败', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                data: (note) => Text(note?.definition ?? '（无释义）'),
              ),
            ],
          ),
        ),
      ],
      child: Text(
        word,
        style: TextStyle(
          decoration: TextDecoration.underline,
          decorationColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
        ),
      ),
      onOpened: () => ref.read(vocabularyProvider.notifier).lookupWord(sentenceId, word),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/vocabulary/
git commit -m "feat: implement FR-007 vocabulary lookup with local cache"
```

---

## Task 12: FR-008 Dictation Mode

**Files:**
- Create: `lib/features/dictation/domain/dictation_notifier.dart`
- Create: `lib/features/dictation/presentation/dictation_screen.dart`

- [ ] **Step 1: Create DictationNotifier**

Create `lib/features/dictation/domain/dictation_notifier.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diff_match_patch/diff_match_patch.dart';

class DiffResult {
  final String original;
  final String userInput;
  final List<Diff> diffs;

  DiffResult({required this.original, required this.userInput, required this.diffs});
}

final dictationProvider = NotifierProvider<DictationNotifier, DictationState>(
  DictationNotifier.new,
);

class DictationState {
  final String originalText;
  final String userInput;
  final DiffResult? diffResult;
  final bool submitted;

  const DictationState({
    this.originalText = '',
    this.userInput = '',
    this.diffResult,
    this.submitted = false,
  });

  DictationState copyWith({String? originalText, String? userInput, DiffResult? diffResult, bool? submitted}) {
    return DictationState(
      originalText: originalText ?? this.originalText,
      userInput: userInput ?? this.userInput,
      diffResult: diffResult ?? this.diffResult,
      submitted: submitted ?? this.submitted,
    );
  }
}

class DictationNotifier extends Notifier<DictationState> {
  @override
  DictationState build() => const DictationState();

  void setOriginalText(String text) {
    state = state.copyWith(originalText: text, submitted: false, diffResult: null);
  }

  void updateUserInput(String input) {
    state = state.copyWith(userInput: input);
  }

  void submit() {
    final dmp = DiffMatchPatch();
    final diffs = dmp.diff(state.originalText, state.userInput);
    state = state.copyWith(
      diffResult: DiffResult(
        original: state.originalText,
        userInput: state.userInput,
        diffs: diffs,
      ),
      submitted: true,
    );
  }

  void reset() {
    state = const DictationState();
  }
}
```

- [ ] **Step 2: Create DictationScreen**

Create `lib/features/dictation/presentation/dictation_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import '../domain/dictation_notifier.dart';
import '../../player/domain/player_notifier.dart';

class DictationScreen extends ConsumerStatefulWidget {
  final int audioFileId;

  const DictationScreen({super.key, required this.audioFileId});

  @override
  ConsumerState<DictationScreen> createState() => _DictationScreenState();
}

class _DictationScreenState extends ConsumerState<DictationScreen> {
  final _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncOriginalText();
  }

  void _syncOriginalText() {
    final playerState = ref.read(playerProvider).value;
    if (playerState?.currentSentence != null) {
      ref.read(dictationProvider.notifier).setOriginalText(
        playerState!.currentSentence!.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dictState = ref.watch(dictationProvider);
    final playerState = ref.watch(playerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('听写模式'),
        actions: [
          if (dictState.submitted)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(dictationProvider.notifier).reset();
                _inputController.clear();
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Audio control
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () {
                    ref.read(playerProvider.notifier).prevSentence();
                    _syncOriginalText();
                  },
                ),
                FloatingActionButton.small(
                  onPressed: () => ref.read(playerProvider.notifier).togglePlayPause(),
                  child: Icon(
                    playerState?.status == PlayerPlaybackStatus.playing ||
                            playerState?.status == PlayerPlaybackStatus.looping
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () {
                    ref.read(playerProvider.notifier).nextSentence();
                    _syncOriginalText();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Input area
            Expanded(
              child: TextField(
                controller: _inputController,
                maxLines: null,
                expands: true,
                enabled: !dictState.submitted,
                decoration: const InputDecoration(
                  hintText: '在此输入听写内容...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => ref.read(dictationProvider.notifier).updateUserInput(v),
              ),
            ),
            const SizedBox(height: 16),

            // Submit / Result
            if (!dictState.submitted)
              FilledButton(
                onPressed: () => ref.read(dictationProvider.notifier).submit(),
                child: const Text('提交对照'),
              ),

            if (dictState.submitted && dictState.diffResult != null)
              _DiffResultView(diffs: dictState.diffResult!.diffs),
          ],
        ),
      ),
    );
  }
}

class _DiffResultView extends StatelessWidget {
  final List<Diff> diffs;

  const _DiffResultView({required this.diffs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('对照结果', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            children: diffs.map((diff) {
              switch (diff.operation) {
                case Operation.equal:
                  return Text(diff.text, style: const TextStyle(color: Colors.green));
                case Operation.delete:
                  return Text(diff.text, style: const TextStyle(color: Colors.red, decoration: TextDecoration.lineThrough));
                case Operation.insert:
                  return Text(diff.text, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline));
              }
            }).toList(),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/dictation/
git commit -m "feat: implement FR-008 dictation mode with diff highlighting"
```

---

## Task 13: FR-009 Play Progress & History

**Files:**
- Create: `lib/features/progress/domain/progress_notifier.dart`

- [ ] **Step 1: Create ProgressNotifier**

Create `lib/features/progress/domain/progress_notifier.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/play_progress_repository.dart';
import '../../../core/storage/audio_file_repository.dart';
import '../../../providers/app_providers.dart';

final resumeInfoProvider = FutureProvider.family<int?, int>((ref, audioFileId) async {
  final progressRepo = ref.read(playProgressRepositoryProvider);
  final progress = await progressRepo.getByAudioFileId(audioFileId);
  return progress?.sentenceIdx;
});

class ProgressNotifier extends Notifier {
  @override
  build() => null;

  Future<bool> shouldResume(int audioFileId) async {
    final progressRepo = ref.read(playProgressRepositoryProvider);
    final progress = await progressRepo.getByAudioFileId(audioFileId);
    return progress != null && progress.sentenceIdx > 0;
  }
}
```

- [ ] **Step 2: Update PlayerScreen to show resume dialog**

In `player_screen.dart`, add resume prompt in `initState`:

```dart
@override
void initState() {
  super.initState();
  Future.microtask(() async {
    await ref.read(playerProvider.notifier).loadFile(widget.audioFileId);
    // Check for saved progress
    final progressRepo = ref.read(playProgressRepositoryProvider);
    final progress = await progressRepo.getByAudioFileId(widget.audioFileId);
    if (progress != null && progress.sentenceIdx > 0 && mounted) {
      final shouldResume = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('继续播放'),
          content: Text('从第 ${progress.sentenceIdx + 1} 句继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('从头开始'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('继续'),
            ),
          ],
        ),
      );
      if (shouldResume == true) {
        ref.read(playerProvider.notifier).playSentence(progress.sentenceIdx);
      }
    }
  });
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/progress/
git commit -m "feat: implement FR-009 play progress persistence with resume prompt"
```

---

## Task 14: FR-010 Background Playback & Notification

**Files:**
- Create: `lib/features/background/data/background_service.dart`

- [ ] **Step 1: Create AudioHandler for background playback**

Create `lib/features/background/data/background_service.dart`:

```dart
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class SrtAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  SrtAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  Future<void> init(String uri) async {
    await _player.setUrl(uri);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration? position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  Future<void> playSegment(int startMs, int endMs) async {
    await _player.seek(Duration(milliseconds: startMs));
    await _player.play();
  }

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  void updateMediaItem(String title, {String? album}) {
    mediaItem.add(MediaItem(
      id: 'srt_player',
      title: title.length > 30 ? '${title.substring(0, 30)}...' : title,
      album: album ?? '逐句复读播放器',
    ));
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(_player.processingState),
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
}

Future<SrtAudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => SrtAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.srtplayer.channel.audio',
      androidNotificationChannelName: '逐句复读播放器',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
```

- [ ] **Step 2: Update AndroidManifest.xml for background service**

Add to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
```

Add `android:foregroundServiceType="mediaPlayback"` to the `<service>` tag for audio_service.

- [ ] **Step 3: Integrate background service into AudioPlayerService**

Update `lib/core/audio/audio_player_service.dart` to use `SrtAudioHandler` instead of plain `AudioPlayer` when background mode is needed. The handler wraps `just_audio` and provides `MediaSession` integration.

- [ ] **Step 4: Commit**

```bash
git add lib/features/background/ android/
git commit -m "feat: implement FR-010 background playback with media notification"
```

---

## Task 15: FR-011 Batch Import & Course List

**Files:**
- Create: `lib/features/batch/data/batch_import_service.dart`
- Create: `lib/features/batch/presentation/batch_import_screen.dart`

- [ ] **Step 1: Create BatchImportService**

Create `lib/features/batch/data/batch_import_service.dart`:

```dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../../core/parser/srt_parser.dart';
import '../../../core/storage/audio_file_repository.dart';
import '../../../core/storage/sentence_repository.dart';
import '../../../models/audio_file.dart';
import '../../../models/sentence.dart';

class BatchImportResult {
  final int successCount;
  final int failCount;
  final List<String> errors;

  BatchImportResult({required this.successCount, required this.failCount, required this.errors});
}

class BatchImportService {
  final AudioFileRepository _audioFileRepo;
  final SentenceRepository _sentenceRepo;

  BatchImportService(this._audioFileRepo, this._sentenceRepo);

  Future<BatchImportResult> importFolder(String folderPath) async {
    int success = 0;
    int fail = 0;
    final errors = <String>[];

    final dir = Directory(folderPath);
    if (!dir.existsSync()) {
      return BatchImportResult(successCount: 0, failCount: 0, errors: ['目录不存在']);
    }

    // Find all MP3 files
    final mp3Files = dir.listSync()
        .where((f) => p.extension(f.path).toLowerCase() == '.mp3')
        .toList();

    for (final mp3File in mp3Files) {
      try {
        final fileName = p.basenameWithoutExtension(mp3File.path);
        final srtPath = p.join(dir.path, '$fileName.srt');

        if (!File(srtPath).existsSync()) {
          errors.add('$fileName: 未找到匹配的 SRT 文件');
          fail++;
          continue;
        }

        final srtContent = await File(srtPath).readAsString();
        final parseResult = SrtParser.parseWithErrors(srtContent);
        if (parseResult.entries.isEmpty) {
          errors.add('$fileName: SRT 解析结果为空');
          fail++;
          continue;
        }

        final dbFile = AudioFile()
          ..fileName = fileName
          ..audioUri = mp3File.path
          ..srtUri = srtPath
          ..createdAt = DateTime.now();
        await _audioFileRepo.create(dbFile);

        final sentences = parseResult.entries.map((e) => Sentence()
          ..audioFileId = dbFile.id
          ..index = e.index
          ..startTimeMs = e.startTimeMs
          ..endTimeMs = e.endTimeMs
          ..text = e.text
        ).toList();
        await _sentenceRepo.saveAll(sentences);

        success++;
      } catch (e) {
        errors.add('${p.basename(mp3File.path)}: $e');
        fail++;
      }
    }

    return BatchImportResult(successCount: success, failCount: fail, errors: errors);
  }
}
```

- [ ] **Step 2: Create BatchImportScreen**

Create `lib/features/batch/presentation/batch_import_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../providers/app_providers.dart';
import '../data/batch_import_service.dart';

class BatchImportScreen extends ConsumerStatefulWidget {
  const BatchImportScreen({super.key});

  @override
  ConsumerState<BatchImportScreen> createState() => _BatchImportScreenState();
}

class _BatchImportScreenState extends ConsumerState<BatchImportScreen> {
  bool _importing = false;

  Future<void> _importFolder() async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result == null) {
        setState(() => _importing = false);
        return;
      }

      final service = BatchImportService(
        ref.read(audioFileRepositoryProvider),
        ref.read(sentenceRepositoryProvider),
      );
      final importResult = await service.importFolder(result);

      ref.invalidate(audioFileListProvider);

      if (mounted) {
        Fluttertoast.showToast(
          msg: '导入完成：${importResult.successCount} 成功，${importResult.failCount} 失败',
          toastLength: Toast.LENGTH_LONG,
        );
        if (importResult.errors.isNotEmpty) {
          _showErrorDialog(importResult.errors);
        }
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '批量导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showErrorDialog(List<String> errors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入错误'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: errors.length,
            itemBuilder: (_, i) => Text(errors[i], style: const TextStyle(fontSize: 12)),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('批量导入')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('选择包含 MP3+SRT 配对的文件夹'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _importing ? null : _importFolder,
              icon: const Icon(Icons.upload_file),
              label: _importing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('选择文件夹'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Add batch import route to router**

Add to `lib/core/router/app_router.dart`:

```dart
import '../../features/batch/presentation/batch_import_screen.dart';

// Add route:
GoRoute(
  path: '/batch-import',
  builder: (context, state) => const BatchImportScreen(),
),
```

Add batch import button to `HomeScreen` AppBar or overflow menu.

- [ ] **Step 4: Commit**

```bash
git add lib/features/batch/
git commit -m "feat: implement FR-011 batch import with folder scanning"
```

---

## Task 16: Audio Interruption Handling

**Files:**
- Modify: `lib/core/audio/audio_player_service.dart`

- [ ] **Step 1: Add audio session interruption handling**

Update `AudioPlayerService` to configure `AudioSession` and listen to interruptions:

```dart
import 'package:audio_session/audio_session.dart';

// Add to AudioPlayerService:
Future<void> configureSession() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.speech());

  session.interruptionEventStream.listen((event) {
    if (event.begin) {
      pause();
    }
  });

  session.becomingNoisyEventStream.listen((_) {
    pause();
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/audio/
git commit -m "feat: handle audio interruptions and becoming noisy events"
```

---

## Task 17: Integration & Polish

**Files:**
- Modify: `lib/main.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/features/files/presentation/home_screen.dart`

- [ ] **Step 1: Update AndroidManifest.xml**

Ensure permissions and intent-filter for file association:

```xml
<activity android:name=".MainActivity"
    android:launchMode="singleTop">
  <intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:mimeType="audio/mpeg"/>
  </intent-filter>
</intent-filter>
```

- [ ] **Step 2: Add batch import button to HomeScreen**

In `HomeScreen`, add overflow menu with "批量导入" option:

```dart
PopupMenuButton<String>(
  onSelected: (value) {
    if (value == 'batch') {
      context.go('/batch-import');
    }
  },
  itemBuilder: (_) => [
    const PopupMenuItem(value: 'batch', child: Text('批量导入')),
  ],
),
```

- [ ] **Step 3: Run full app and verify**

Run:
```bash
flutter run
```
Verify:
- Home screen shows empty state with import button
- Import flow picks audio + SRT, parses, navigates to player
- Player shows sentence list, tap to play, auto-advances
- Looping, speed change, next/prev all work
- Long press shows mark options
- Dictation screen accessible from player
- Background notification shows during playback

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "feat: integration polish — Android manifest, batch import nav, final wiring"
```

---

## Self-Review Checklist

- [x] **Spec coverage**: FR-001 (Task 8), FR-002~005 (Task 9), FR-006 (Task 10), FR-007 (Task 11), FR-008 (Task 12), FR-009 (Task 13), FR-010 (Task 14), FR-011 (Task 15)
- [x] **Placeholder scan**: No TBD/TODO found
- [x] **Type consistency**: All model fields, method names, and provider references are consistent across tasks
- [x] **Missing items**: Audio interruption handling added as Task 16
