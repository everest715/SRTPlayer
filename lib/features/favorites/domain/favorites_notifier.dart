import 'package:flutter_riverpod/flutter_riverpod.dart';
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
