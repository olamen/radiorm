import 'dart:math';

import 'package:flutter/material.dart';


import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../l10n/localization.dart'; 
import 'package:audio_service/audio_service.dart'; 
import 'package:provider/provider.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  
  

  
  bool _isPlaying = false;
  

  
  late AudioHandler _audioHandler;

  @override
  void initState() {
    super.initState();
    
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ));

    
    
    _audioHandler = Provider.of<AudioHandler>(context, listen: false);

    
    _audioHandler.playbackState.listen((state) {
      final playing = state.playing;
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    
    if (_audioHandler.playbackState.value.playing) {
       setState(() {
         _isPlaying = true;
       });
    }
  }

  @override
  void dispose() {
    
    super.dispose();
  }

  

  Future<void> _togglePlayback() async {
    final localizations = AppLocalizations.of(context);

    if (_isPlaying) {
      await _audioHandler.pause(); 
    } else {
       
       
       
       
       

       await _audioHandler.play(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isRtl = Localizations.localeOf(context).languageCode == 'ar';

    
    
    
    
    


    return Scaffold(
      backgroundColor: Colors.white, 

      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              
              Image.asset(
                'assets/images/logo.png',
                width: 250, 
                height: 250,
              ),
              const SizedBox(height: 0), 
              AnimatedWave(
                  isPlaying: _isPlaying, 
                  waveColor: Colors.green[700]!), 
              const SizedBox(height: 50), 
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700], 
                  foregroundColor: Colors.white, 
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 12), 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  elevation: 3, 
                ),
                icon: Transform.scale(
                  scaleX: isRtl ? -1 : 1, 
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow, 
                    color: Colors.white,
                    size: 30, 
                  ),
                ),
                label: Text(
                  _isPlaying 
                      ? (localizations?.stopButton ?? 'Stop')
                      : (localizations?.playButton ?? 'Play'),
                  style: const TextStyle(fontSize: 22), 
                ),
                onPressed: _togglePlayback, 
              ),
              const SizedBox(height: 40),
              Text(
                localizations?.liveStream ?? 'Live Stream', 
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black54, 
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedWave extends StatefulWidget {
  final bool isPlaying;
  final Color waveColor; 
  const AnimatedWave(
      {super.key, required this.isPlaying, required this.waveColor});

  @override
  State<AnimatedWave> createState() => _AnimatedWaveState();
}

class _AnimatedWaveState extends State<AnimatedWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _barHeights =
      List.generate(20, (index) => 10.0); 
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), 
    )..addListener(() {
        setState(() {
          for (int i = 0; i < _barHeights.length; i++) {
            
            
            final double baseHeight = 10.0;
            final double maxFluctuation = 25.0;
            final double sineValue = sin(_controller.value * 2 * pi + i * 0.2);
            _barHeights[i] = baseHeight +
                (sineValue * maxFluctuation * 0.5) +
                (_random.nextDouble() * maxFluctuation * 0.5);
            _barHeights[i] = _barHeights[i].clamp(10.0, 35.0); 
          }
        });
      });

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
      
      setState(() {
        for (int i = 0; i < _barHeights.length; i++) {
          _barHeights[i] = 10.0; 
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100, 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _barHeights.map((height) {
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 2.5), 
            child: Container(
              width: 7, 
              height: height,
              decoration: BoxDecoration(
                color: widget.waveColor, 
                borderRadius: BorderRadius.circular(3), 
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
