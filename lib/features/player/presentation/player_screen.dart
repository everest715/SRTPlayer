import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../domain/player_notifier.dart';
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
  bool _resumeChecked = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(playerProvider.notifier).loadFile(widget.audioFileId);

      if (!_resumeChecked && mounted) {
        _resumeChecked = true;
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
      }
    });
  }

  void _scrollToSentence(int index) {
    if (!_scrollController.hasClients) return;
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
        title: const Text('播放中'),
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

  void _showSentenceMenu(BuildContext context, int? sentenceId) {
    if (sentenceId == null) return;
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
            '${(relativePos ~/ 1000)}s',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Expanded(
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (v) => onSeek(startMs + (v * durationMs).round()),
            ),
          ),
          Text(
            '${(durationMs ~/ 1000)}s',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
