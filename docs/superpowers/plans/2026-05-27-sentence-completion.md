# Sentence Completion Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Track per-sentence playback completion and reflect it in UI (gray text for completed sentences, alternate icon for fully-completed audio files).

**Architecture:** Add `completed` column to sentences table, update Sentence model and repository, mark sentences completed in PlayerNotifier when playback passes their end time, and update SentenceCard and _AudioFileListTile UI accordingly.

**Tech Stack:** Flutter, Riverpod, sqflite, just_audio

---

### Task 1: Database migration — add `completed` column

**Files:**
- Modify: `lib/core/storage/database.dart`

- [ ] **Step 1: Update database version and add migration**

In `database.dart`, change `version: 3` to `version: 4` and add migration in `onUpgrade`:

```dart
if (oldVersion < 4) {
  await db.execute('ALTER TABLE sentences ADD COLUMN completed INTEGER NOT NULL DEFAULT 0');
}
```

Also add `completed INTEGER NOT NULL DEFAULT 0` to the `CREATE TABLE sentences` statement in `onCreate`.

- [ ] **Step 2: Run `flutter analyze` to verify no errors**

Run: `C:\flutter-sdk\bin\flutter.bat analyze lib/core/storage/database.dart`
Expected: No errors related to the change.

- [ ] **Step 3: Commit**

```bash
git add lib/core/storage/database.dart
git commit -m "feat: add completed column to sentences table (db v4)"
```

---

### Task 2: Update Sentence model

**Files:**
- Modify: `lib/models/sentence.dart`

- [ ] **Step 1: Add `completed` field to Sentence class**

Add `final bool completed;` field after `markStatus`. Update constructor to include `this.completed = false`. Update `toMap()` to include `'completed': completed ? 1 : 0`. Update `fromMap()` to read `completed: (map['completed'] as int?) == 1`. Update `copyWith()` to include `bool? completed` parameter with `completed ?? this.completed`.

- [ ] **Step 2: Run `flutter analyze` to verify**

Run: `C:\flutter-sdk\bin\flutter.bat analyze lib/models/sentence.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/models/sentence.dart
git commit -m "feat: add completed field to Sentence model"
```

---

### Task 3: Add `markCompleted` to SentenceRepository

**Files:**
- Modify: `lib/core/storage/sentence_repository.dart`

- [ ] **Step 1: Add markCompleted method**

```dart
Future<void> markCompleted(int sentenceId) async {
  final db = await _db();
  await db.update(
    'sentences',
    {'completed': 1},
    where: 'id = ?',
    whereArgs: [sentenceId],
  );
}
```

Also add a method to check if all sentences of an audio file are completed:

```dart
Future<bool> isAllCompleted(int audioFileId) async {
  final db = await _db();
  final result = await db.rawQuery(
    'SELECT COUNT(*) AS cnt FROM sentences WHERE audioFileId = ? AND completed = 0',
    [audioFileId],
  );
  return (result.first['cnt'] as int) == 0;
}
```

- [ ] **Step 2: Run `flutter analyze` to verify**

Run: `C:\flutter-sdk\bin\flutter.bat analyze lib/core/storage/sentence_repository.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/core/storage/sentence_repository.dart
git commit -m "feat: add markCompleted and isAllCompleted to SentenceRepository"
```

---

### Task 4: Mark sentence completed in PlayerNotifier

**Files:**
- Modify: `lib/features/player/domain/player_notifier.dart`
- Modify: `lib/features/player/domain/player_state.dart`

- [ ] **Step 1: Update PlayerState.copyWith to propagate sentence list changes**

The sentences list in PlayerState needs to support in-place updates. No change needed to copyWith itself — we will pass a new sentences list.

- [ ] **Step 2: In PlayerNotifier._onSentenceComplete, mark sentence completed**

In `_onSentenceComplete()`, before the existing logic (looping/continuous/stop), add:

```dart
final completedSentence = current.sentences[current.currentSentenceIndex];
final sentenceRepo = ref.read(sentenceRepositoryProvider);
await sentenceRepo.markCompleted(completedSentence.id!);

// Update the sentence in state
final updatedSentences = List<Sentence>.from(current.sentences);
updatedSentences[current.currentSentenceIndex] = completedSentence.copyWith(completed: true);
state = AsyncData(current.copyWith(sentences: updatedSentences));
```

Note: Need to re-read `current` after the state update since `_onSentenceComplete` is called from the position stream. The `_onSentenceComplete` method should read the latest state. Since we call `state = AsyncData(...)` to mark completed before the playSentence call, the subsequent logic should read from the updated state. Restructure `_onSentenceComplete`:

```dart
Future<void> _onSentenceComplete() async {
  var current = state.value;
  if (current == null) return;

  // Mark current sentence as completed
  final completedSentence = current.sentences[current.currentSentenceIndex];
  final sentenceRepo = ref.read(sentenceRepositoryProvider);
  await sentenceRepo.markCompleted(completedSentence.id!);

  final updatedSentences = List<Sentence>.from(current.sentences);
  updatedSentences[current.currentSentenceIndex] = completedSentence.copyWith(completed: true);
  current = current.copyWith(sentences: updatedSentences);
  state = AsyncData(current);

  if (current.looping) {
    await playSentence(current.currentSentenceIndex);
  } else if (current.continuousPlay && current.currentSentenceIndex < current.sentences.length - 1) {
    await playSentence(current.currentSentenceIndex + 1);
  } else {
    await _audioService?.pause();
    state = AsyncData(current.copyWith(status: PlayerPlaybackStatus.idle));
  }
}
```

- [ ] **Step 3: Run `flutter analyze` to verify**

Run: `C:\flutter-sdk\bin\flutter.bat analyze lib/features/player/domain/`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/player/domain/player_notifier.dart
git commit -m "feat: mark sentence completed on playback end"
```

---

### Task 5: Update SentenceCard UI — gray text for completed sentences

**Files:**
- Modify: `lib/features/player/presentation/sentence_card.dart`

- [ ] **Step 1: Apply gray color for completed sentences**

In `build()`, change the `textColor` logic:

```dart
final textColor = sentence.completed
    ? theme.disabledColor
    : isCurrent
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
```

- [ ] **Step 2: Run `flutter analyze` to verify**

Run: `C:\flutter-sdk\bin\flutter.bat analyze lib/features/player/presentation/sentence_card.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/player/presentation/sentence_card.dart
git commit -m "feat: show completed sentence text in gray"
```

---

### Task 6: Update audio file list — completed icon for fully-played audio

**Files:**
- Modify: `lib/providers/app_providers.dart`
- Modify: `lib/features/files/presentation/home_screen.dart`

- [ ] **Step 1: Add a provider to check if an audio file's sentences are all completed**

In `app_providers.dart`:

```dart
final audioCompletedProvider = FutureProvider.family<bool, int>((ref, audioFileId) {
  final repo = ref.read(sentenceRepositoryProvider);
  return repo.isAllCompleted(audioFileId);
});
```

- [ ] **Step 2: Update `_AudioFileListTile` to use completion-aware icon**

Change `_AudioFileListTile` from `ConsumerWidget` to accept and use the completion state. In `home_screen.dart`, update the `build` method:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final completedAsync = ref.watch(audioCompletedProvider(file.id!));
  final isCompleted = completedAsync.valueOrNull ?? false;

  return Dismissible(
    // ... existing Dismissible config ...
    child: ListTile(
      leading: Icon(
        file.status == 'offline'
            ? Icons.cloud_off
            : isCompleted
                ? Icons.check_circle
                : Icons.audiotrack,
        color: file.status == 'offline'
            ? Colors.grey
            : isCompleted
                ? Colors.green
                : null,
      ),
      // ... rest unchanged ...
    ),
  );
}
```

- [ ] **Step 3: Invalidate audioCompletedProvider where needed**

In `_importFile()` and after delete, add `ref.invalidate(audioCompletedProvider(file.id!))` where appropriate. Since `audioFileListProvider` is already invalidated after import/delete and the completion provider is `family`-scoped per audioFileId, it will be re-fetched when the audio list rebuilds. No additional invalidation needed.

- [ ] **Step 4: Run `flutter analyze` to verify**

Run: `C:\flutter-sdk\bin\flutter.bat analyze lib/`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/app_providers.dart lib/features/files/presentation/home_screen.dart
git commit -m "feat: show completed icon for fully-played audio files"
```

---

### Task 7: Build, install and verify

- [ ] **Step 1: Build release APK**

Run:
```bash
$env:JAVA_HOME = "D:\Android\jdk-17.0.19+10"; C:\flutter-sdk\bin\flutter.bat build apk --release
```
Expected: BUILD SUCCESSFUL

- [ ] **Step 2: Install to device**

Run:
```bash
$env:JAVA_HOME = "D:\Android\jdk-17.0.19+10"; C:\flutter-sdk\bin\flutter.bat install build\app\outputs\flutter-apk\app-release.apk
```
Expected: Installing... success

- [ ] **Step 3: Manual test**

1. Import an audio with SRT
2. Play through sentences — verify text turns gray after each sentence completes
3. Play all sentences — verify audio icon changes to green checkmark on home screen
4. Re-enter the same audio — verify completed states persist (gray text still shows)
