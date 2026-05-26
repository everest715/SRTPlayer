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
                Icon(
                  sentence.markStatus == MarkStatus.diff
                      ? Icons.new_releases
                      : sentence.markStatus == MarkStatus.focus
                          ? Icons.star
                          : Icons.check_circle,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMs(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
