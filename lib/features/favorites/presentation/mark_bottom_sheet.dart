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
