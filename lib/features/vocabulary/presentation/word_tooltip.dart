import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/vocabulary_notifier.dart';

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
