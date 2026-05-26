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
