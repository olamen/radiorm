import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:stream2/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;


class AudioPlayerWidget extends StatefulWidget {
  const AudioPlayerWidget({super.key});

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _playAudio() async {
    const m3uUrl = 'https://ec6.yesstreaming.net:1570/radiorm1/1/winamp.m3u';
    try {
      final response = await http.get(Uri.parse(m3uUrl));
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        final streamUrl = lines.firstWhere(
          (line) => line.startsWith('http'),
          orElse: () => '',
        );
        if (streamUrl.isNotEmpty) {
          await _audioPlayer
              .setAudioSource(AudioSource.uri(Uri.parse(streamUrl)));
          await _audioPlayer.play();
          setState(() {
            _isPlaying = true;
          });
          _animationController.forward();
        } else {
          print('No valid stream URL found in .m3u file.');
        }
      } else {
        print('Failed to load .m3u file: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading .m3u file: $e');
    }
  }

  void _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
      _animationController.reverse();
    } else {
      _playAudio();
    }
  }

  void _seekBack(Duration duration) {
    final currentPosition = _audioPlayer.position;
    final newPosition = currentPosition - duration;
    _audioPlayer.seek(newPosition);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _togglePlayback,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedIcon(
                icon: AnimatedIcons.play_pause,
                progress: _animationController,
              ),
              const SizedBox(width: 8),
              Text(_isPlaying
                  ? AppLocalizations.of(context).pause
                  : AppLocalizations.of(context).playRadioStream),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          color: Colors.blue,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('back', style: TextStyle(color: Colors.white, fontSize: 26)),
            ],
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _seekBack(const Duration(minutes: 1)),
              child: const Text('1 min'),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _seekBack(const Duration(minutes: 5)),
              child: const Text('5 min'),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _seekBack(const Duration(minutes: 10)),
              child: const Text('10 min'),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _seekBack(const Duration(minutes: 30)),
              child: const Text('30 min'),
            ),
          ],
        ),
      ],
    );
  }
}