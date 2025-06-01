import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

Future<AudioHandler> initAudioService() async {
  final session = await AudioSession.instance;
  await session.configure(AudioSessionConfiguration.music());

  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.radio.mauritanie.channel.audio',
      androidNotificationChannelName: 'Radio Mauritanie',
      androidNotificationOngoing: true,
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  MyAudioHandler() {
    _player.playbackEventStream.listen((event) {
      playbackState.add(_transformEvent(event));
    });

    mediaItem.add(const MediaItem(
      id: 'https://stream-url.mp3', // remplace dynamiquement plus tard
      title: 'Radio Mauritanie',
      artist: 'En direct',
    ));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  Future<void> setStreamUrl(String url) async {
    await _player.setUrl(url);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.pause,
        MediaControl.play,
        MediaControl.stop,
      ],
      playing: _player.playing,
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
    );
  }
}
