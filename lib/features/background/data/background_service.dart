import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class SrtAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  SrtAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  Future<void> init(String uri) async {
    await _player.setUrl(uri);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration? position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  Future<void> playSegment(int startMs, int endMs) async {
    await _player.seek(Duration(milliseconds: startMs));
    await _player.play();
  }

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(_player.processingState),
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
}

Future<SrtAudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => SrtAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.srtplayer.channel.audio',
      androidNotificationChannelName: '逐句复读播放器',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
