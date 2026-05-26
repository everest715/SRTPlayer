import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

enum PlayerPlaybackState { idle, playing, paused, looping }

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  PlayerPlaybackState _state = PlayerPlaybackState.idle;
  bool _looping = false;
  bool _sessionConfigured = false;

  PlayerPlaybackState get state => _state;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  double get speed => _player.speed;
  bool get isLooping => _looping;
  AudioPlayer get player => _player;

  Stream<PlayerPlaybackState> get stateStream =>
      _player.playbackEventStream.map((_) => _state);
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<void> get playerCompleteStream =>
      _player.playerStateStream.where((s) => s.processingState == ProcessingState.completed);

  Future<void> setUrl(String uri) async {
    await _configureSession();
    await _player.setUrl(uri);
    _state = PlayerPlaybackState.idle;
  }

  Future<void> _configureSession() async {
    if (_sessionConfigured) return;
    _sessionConfigured = true;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        pause();
      }
    });

    session.becomingNoisyEventStream.listen((_) {
      pause();
    });
  }

  Future<void> playSegment(int startMs, int endMs) async {
    if (_player.playing) {
      await _player.pause();
    }
    await _player.seek(Duration(milliseconds: startMs));
    _state = _looping ? PlayerPlaybackState.looping : PlayerPlaybackState.playing;
    await _player.play();
  }

  Future<void> play() async {
    _state = _looping ? PlayerPlaybackState.looping : PlayerPlaybackState.playing;
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
    _state = PlayerPlaybackState.paused;
  }

  Future<void> seekTo(int ms) async {
    await _player.seek(Duration(milliseconds: ms));
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  void toggleLooping() {
    _looping = !_looping;
    if (_state == PlayerPlaybackState.playing && _looping) {
      _state = PlayerPlaybackState.looping;
    } else if (_state == PlayerPlaybackState.looping && !_looping) {
      _state = PlayerPlaybackState.playing;
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _state = PlayerPlaybackState.idle;
    _looping = false;
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
