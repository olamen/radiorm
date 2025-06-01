import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart'; 

class AudioPlayerService extends BaseAudioHandler with SeekHandler {
  late AudioPlayer _audioPlayer;
  
  bool _wasPlayingBeforeInterruption = false; 

  
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
               audioServiceProcessingState != AudioProcessingState.completed) MediaControl.stop,
        ],
        processingState: audioServiceProcessingState,

        
        
        
        
      ));
    });

    
    mediaItem.add(const MediaItem(
      id: 'radio_stream', 
      album: "Live Radio", 
      title: "Radio Mauritania Live", 
      artist: "Radio Mauritania", 
      artUri: null, 
      
    ));

    
    const streamUrl = 'https://ec6.yesstreaming.net:2760/stream';
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

  
  @override
  Future<void> play() async {
    
    final session = await AudioSession.instance; 
    final sessionActivated = await session.setActive(true); 
    if (sessionActivated) {
       
       if (_audioPlayer.playerState.processingState == ProcessingState.ready ||
           _audioPlayer.playerState.processingState == ProcessingState.buffering ||
           _audioPlayer.playerState.playing) {
         _audioPlayer.play();
       } else if (_audioPlayer.playerState.processingState == ProcessingState.idle ||
                  _audioPlayer.playerState.processingState == ProcessingState.completed) {
         
          const streamUrl = 'https://ec6.yesstreaming.net:2760/stream';
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
  Future<void> seek(Duration position) async {
    
  }

  @override
  Future<void> onTaskRemoved() async {
    
    await super.onTaskRemoved();
  }

   @override
  Future<void> onStop() async {
     
     await _audioPlayer.stop();
     await _audioPlayer.dispose(); 
     final session = await AudioSession.instance; 
     await session.setActive(false); 
     await super.stop(); 
  }

   
   


  
}


Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => AudioPlayerService(),
    config: const AudioServiceConfig( 
      androidNotificationChannelId: 'com.example.myapp.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'mipmap/ic_launcher', 
      
    ),
  );
}
