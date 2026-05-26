import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      final cached = await repo.getByWord(sentenceId, word);
      if (cached != null) return cached;

      final note = WordNote(
        sentenceId: sentenceId,
        word: word,
        definition: '（暂无释义）',
      );
      await repo.save(note);
      return note;
    });
  }
}
