import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';

final resumeInfoProvider = FutureProvider.family<int?, int>((ref, audioFileId) async {
  final progressRepo = ref.read(playProgressRepositoryProvider);
  final progress = await progressRepo.getByAudioFileId(audioFileId);
  return progress?.sentenceIdx;
});
