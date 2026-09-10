import 'dart:math';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:radiomr/const.dart';
import 'package:radiomr/pages/server_driven_page.dart';
import 'package:radiomr/pages/youtube_channel_page.dart';
import 'package:radiomr/pages/youtube_webview_page.dart';
import 'package:radiomr/widgets/audio_player_service.dart';
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

  final List<Map<String, String>> _stations = [
    {
      'name': 'إذاعة موريتانيا  ',
      'url': radioStreamUrl,
      'image': 'assets/images/logo.png',
    },
    {
      'name': 'إذاعة القرآن الكريم',
      'url': radioStreamUrl2,
      'image': 'assets/images/logo.png', // Replace with Quran logo if available
    },
  ];

  int _selectedStation = 0;

  @override
  void initState() {
    super.initState();
    _isPlaying = true;
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
    final station = _stations[_selectedStation];
    if (_isPlaying) {
      await _audioHandler.pause();
    } else {
      await (_audioHandler as AudioPlayerService).setStreamUrl(
        station['url']!,
        station['name']!,
        station['name']!,
        station['image']!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isRtl = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 340,
                  padding:
                      const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.09),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.green.withOpacity(0.18),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          _stations[_selectedStation]['image']!,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _stations[_selectedStation]['name']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                          fontFamily: isRtl ? 'Tajawal' : null,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        localizations?.liveStream ?? 'البث الحي',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                          fontFamily: isRtl ? 'Tajawal' : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // شريط تبديل المحطات بشكل كبسولات عصرية
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.08),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_stations.length, (index) {
                      final selected = _selectedStation == index;
                      return GestureDetector(
                        onTap: () async {
                          setState(() {
                            _selectedStation = index;
                          });
                          if (_isPlaying) {
                            final station = _stations[_selectedStation];
                            await (_audioHandler as AudioPlayerService)
                                .setStreamUrl(
                              station['url']!,
                              station['name']!,
                              station['name']!,
                              station['image']!,
                            );
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.green[700]
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.18),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            _stations[index]['name']!,
                            style: TextStyle(
                              color:
                                  selected ? Colors.white : Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              fontFamily: isRtl ? 'Tajawal' : null,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 32),
                // زر التشغيل/الإيقاف بشكل عصري
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPlaying
                        ? const Color.fromARGB(255, 164, 2, 2)
                        : const Color.fromARGB(255, 34, 121, 38),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 56, vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 8,
                    shadowColor: Colors.green.shade200,
                  ),
                  onPressed: _togglePlayback,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isPlaying
                            ? (localizations?.stopButton ?? 'إيقاف')
                            : (localizations?.playButton ?? 'تشغيل'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: isRtl ? 'Tajawal' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.podcasts_rounded,
                        size: 34,
                      ),
                    ],
                  ),
                ),                 
                const SizedBox(height: 16),
 
                const SizedBox(height: 16),
                // زر تصفح قائمة تشغيل اليوتيوب
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const YoutubeChannelPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.playlist_play),
                  label: Text(
                    'قناة اليوتيوب (فيديوهات وقوائم)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: isRtl ? 'Tajawal' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                // موجة صوتية متحركة
                AnimatedWave(
                  isPlaying: _isPlaying,
                  waveColor: Colors.green[700]!,
                ),
              ],
            ),
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
  final List<double> _barHeights = List.generate(20, (index) => 10.0);
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
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
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
