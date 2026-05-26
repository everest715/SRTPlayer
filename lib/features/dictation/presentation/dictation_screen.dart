import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import '../domain/dictation_notifier.dart';
import '../../player/domain/player_notifier.dart';
import '../../player/domain/player_state.dart';

final dmp = DiffMatchPatch();

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
                case DIFF_EQUAL:
                  return Text(diff.text, style: const TextStyle(color: Colors.green));
                case DIFF_DELETE:
                  return Text(diff.text, style: const TextStyle(color: Colors.red, decoration: TextDecoration.lineThrough));
                case DIFF_INSERT:
                  return Text(diff.text, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline));
              }
            }).whereType<Text>().toList(),
          ),
        ],
      ),
    );
  }
}
