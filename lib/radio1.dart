import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:http/http.dart' as http;

// Animated Sound Wave Widget
class AnimatedWaveWidget extends StatefulWidget {
  @override
  _AnimatedWaveWidgetState createState() => _AnimatedWaveWidgetState();
}

class _AnimatedWaveWidgetState extends State<AnimatedWaveWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10,
              height: 20 + _waveController.value * 20,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(5),
              ),
            );
          },
        );
      }),
    );
  }
}

class RadioPlayerScreen extends StatefulWidget {
  final Function(Locale) onLanguageChanged;

  const RadioPlayerScreen({super.key, required this.onLanguageChanged});

  @override
  _RadioPlayerScreenState createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen>
    with SingleTickerProviderStateMixin {
  final String apiUrl =
      'https://ec6.yesstreaming.net:1570/api/links/?t=web&l=radiorm1&c=1';
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  late AnimationController _animationController;
  String streamUrl = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.8,
      upperBound: 1.2,
    )..addListener(() {
        setState(() {});
      });
  }

  Future<void> _fetchStreamUrl() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        print("Stream okkkk");
        final String htmlContent = response.body;

        // Extract stream URL from the HTML using RegExp
        final RegExp regex = RegExp(r'"mp3":\s*"([^"]+)"');
        final match = regex.firstMatch(htmlContent);

        if (match != null) {
          streamUrl = match.group(1)!;
          print("Extracted Stream URL: $streamUrl");
        } else {
          print("Could not find stream URL in the response.");
          streamUrl = '';
        }
      } else {
        print(
            "Failed to fetch stream URL, Status Code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching stream URL: $e");
    }
  }

  void _togglePlayPause() async {
    if (isPlaying) {
      print("is pyaing");
      await _audioPlayer.stop();
      _animationController.reverse();
    } else {
      try {
        if (streamUrl.isEmpty) {
          await _fetchStreamUrl();
        }
        if (streamUrl.isNotEmpty) {
          await _audioPlayer.setSourceUrl(streamUrl);
          await _audioPlayer.resume();
          _animationController.repeat(reverse: true);
        } else {
          print("Stream URL is empty.");
        }
      } catch (e) {
        print("Error playing audio: $e");
      }
    }
    setState(() {
      isPlaying = !isPlaying;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 2, 103, 44).withOpacity(0.8),
        title: Text(
          isArabic ? 'إذاعة موريتانيا' : 'Radio Mauritanie',
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language, color: Colors.white),
            onSelected: widget.onLanguageChanged,
            itemBuilder: (context) => const [
              PopupMenuItem(value: Locale('en'), child: Text('English')),
              PopupMenuItem(value: Locale('fr'), child: Text('Français')),
              PopupMenuItem(value: Locale('ar'), child: Text('العربية')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Image with Fit and Overlay
          Positioned.fill(
            child: Padding(
              padding:
                  const EdgeInsets.all(20.0), // Add padding to create space
              child: Image.asset(
                'assets/images/logo.png', // Replace with your background image path
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),

          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5), // Overlay for readability
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 50),

                // Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),

                // Stream Title
                Text(
                  isArabic ? 'البث المباشر' : 'Live Stream',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 40),

                // Play/Pause Button with Animation
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Transform.scale(
                    scale: _animationController.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: isPlaying
                              ? const Color.fromARGB(255, 164, 151, 3)
                              : Colors.red[400],
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                        if (isPlaying)
                          Positioned(
                            bottom: 8,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Animated Sound Wave Indicator when playing
                isPlaying ? AnimatedWaveWidget() : Container(),

                const Spacer(),

                // News Ticker Text
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 16.0), // Ensure visibility
                  child: Container(
                    height: 50,
                    color: Colors.black.withOpacity(0.8),
                    child: Marquee(
                      text: isArabic
                          ? 'إذاعة موريتانيا على الهواء  |  إذاعة موريتانيا على الهواء  |  '
                          : 'Radio Mauritanie Live  |  Radio Mauritanie Live  |  ',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow,
                      ),
                      scrollAxis: Axis.horizontal,
                      blankSpace: 40.0,
                      velocity: 50.0,
                      pauseAfterRound: const Duration(seconds: 1),
                      startPadding: 10.0,
                      accelerationDuration: const Duration(seconds: 1),
                      accelerationCurve: Curves.linear,
                      decelerationDuration: const Duration(milliseconds: 500),
                      decelerationCurve: Curves.easeOut,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
