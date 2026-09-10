import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class AudioPlayerService extends BaseAudioHandler with SeekHandler {
  late AudioPlayer _audioPlayer;

  bool _wasPlayingBeforeInterruption = false;
  String streamUrl = 'https://ec6.yesstreaming.net:2760/stream';

  AudioPlayerService() {
    _audioPlayer = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;

    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        _wasPlayingBeforeInterruption = _audioPlayer.playing;
        if (_audioPlayer.playing) {
          _audioPlayer.pause();
        }
      } else {
        if (_wasPlayingBeforeInterruption) {
          _audioPlayer.play();
        }
        _wasPlayingBeforeInterruption = false;
      }
    });

    session.becomingNoisyEventStream.listen((_) {
      _audioPlayer.pause();
    });

    _audioPlayer.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;

      AudioProcessingState audioServiceProcessingState;
      switch (processingState) {
        case ProcessingState.idle:
          audioServiceProcessingState = AudioProcessingState.idle;
          break;
        case ProcessingState.loading:
          audioServiceProcessingState = AudioProcessingState.loading;
          break;
        case ProcessingState.buffering:
          audioServiceProcessingState = AudioProcessingState.buffering;
          break;
        case ProcessingState.ready:
          audioServiceProcessingState = AudioProcessingState.ready;
          break;
        case ProcessingState.completed:
          audioServiceProcessingState = AudioProcessingState.completed;
          break;
      }

      playbackState.add(playbackState.value.copyWith(
        playing: isPlaying,
        controls: [
          if (isPlaying) MediaControl.pause else MediaControl.play,
          if (audioServiceProcessingState != AudioProcessingState.idle &&
              audioServiceProcessingState != AudioProcessingState.completed)
            MediaControl.stop,
        ],
        processingState: audioServiceProcessingState,
      ));
    });

    final artworkUri = await _ensureArtworkUri('assets/images/logo.png');
    print('Artwork temporary URI: $artworkUri');

    mediaItem.add(MediaItem(
      id: 'radio_stream',
      album: "إذاعة موريتانيا",
      title: "إذاعة موريتانيا البث المباشر",
      artist: "إذاعة موريتانيا",
      // Use a file:// URI pointing to a temporary copy of the asset so
      // platform notification / lockscreen code can load it.
      artUri: artworkUri,
    ));

    try {
      await _audioPlayer.setUrl(streamUrl);
    } catch (e) {
      print("Error setting stream URL in background: $e");
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
        controls: [],
      ));
      mediaItem.add(mediaItem.value?.copyWith(
        title: "Error Loading Stream",
      ));
    }
  }

  Future<void> setStreamUrl(
      String newUrl, String title, String album, String artUrl) async {
    try {
      streamUrl = newUrl;

      // Stop any currently playing stream
      await _audioPlayer.stop();

      // Update media item
      mediaItem.add(MediaItem(
        id: newUrl,
        album: album,
        title: title,
        artist: "Radio Mauritanie",
        artUri: Uri.parse(artUrl),
      ));

      // Set new stream URL
      await _audioPlayer.setUrl(streamUrl);
      await _audioPlayer.play();

      print("Now streaming: $title ($streamUrl)");
    } catch (e) {
      print("Error switching stream: $e");
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
        controls: [],
      ));
      mediaItem.add(mediaItem.value?.copyWith(
        title: "Error Loading Stream",
      ));
    }
  }

  @override
  Future<void> play() async {
    final session = await AudioSession.instance;
    final sessionActivated = await session.setActive(true);
    if (sessionActivated) {
      if (_audioPlayer.playerState.processingState == ProcessingState.ready ||
          _audioPlayer.playerState.processingState ==
              ProcessingState.buffering ||
          _audioPlayer.playerState.playing) {
        _audioPlayer.play();
      } else if (_audioPlayer.playerState.processingState ==
              ProcessingState.idle ||
          _audioPlayer.playerState.processingState ==
              ProcessingState.completed) {
        try {
          await _audioPlayer.setUrl(streamUrl);
          _audioPlayer.play();
        } catch (e) {
          print("Error re-setting stream URL and playing: $e");
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            playing: false,
            controls: [],
          ));
          mediaItem.add(mediaItem.value?.copyWith(
            title: "Error Loading Stream",
          ));
        }
      }
    }
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();

    final session = await AudioSession.instance;
    await session.setActive(false);
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.completed,
      playing: false,
      controls: [],
    ));

    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> onTaskRemoved() async {
    await super.onTaskRemoved();
  }

  // The audio_service BaseAudioHandler defines `stop()` — an explicit
  // `onStop()` override does not exist in the current API. Remove the
  // incorrect override and provide a private dispose helper if needed.

  /// Ensure the provided asset (packaged in the app) is written to a
  /// temporary file and return a file:// Uri that platform code can load
  /// (needed for lock-screen artwork on some platforms).
  Future<Uri> _ensureArtworkUri(String assetPath) async {
    try {
      // Load asset bytes
      final byteData = await rootBundle.load(assetPath);

      // Get temp directory
      final tempDir = await getTemporaryDirectory();

      // Use a stable filename so it can be reused across runs
      final file = File('${tempDir.path}/radio_artwork.png');

      // Write bytes to file (overwrite if exists)
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      // Debug: print path and existence so we can verify the file was created
      final exists = await file.exists();
      print('Wrote artwork to temporary file: ${file.path} (exists: $exists)');

      return file.uri;
    } catch (e) {
      // On error return an empty URI so callers can handle gracefully
      print('Error writing artwork asset to temp file: $e');
      return Uri();
    }
  }
}

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => AudioPlayerService(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.radiorm.radiormapp.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
}
