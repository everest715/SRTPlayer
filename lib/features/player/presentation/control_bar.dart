import 'package:flutter/material.dart';
import '../domain/player_state.dart';

class ControlBar extends StatelessWidget {
  final PlayerPlaybackStatus status;
  final bool looping;
  final bool continuousPlay;
  final double speed;
  final VoidCallback onPlayPause;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToggleLoop;
  final VoidCallback onToggleContinuousPlay;
  final VoidCallback onSpeedTap;

  const ControlBar({
    super.key,
    required this.status,
    required this.looping,
    required this.continuousPlay,
    required this.speed,
    required this.onPlayPause,
    required this.onPrev,
    required this.onNext,
    required this.onToggleLoop,
    required this.onToggleContinuousPlay,
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
          IconButton(
            icon: Icon(
              continuousPlay ? Icons.all_inclusive : Icons.filter_1,
              color: continuousPlay ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: onToggleContinuousPlay,
            tooltip: continuousPlay ? '连续播放：开' : '连续播放：关',
          ),
        ],
      ),
    );
  }
}
