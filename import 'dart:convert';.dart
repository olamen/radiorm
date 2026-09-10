import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:radiomr/const.dart';
import 'package:radiomr/l10n/localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';

// --- Theme and Colors for Modern Look ---
// Define a central color for a modern, clean look
const Color _primaryColor = Color(0xFF1DB954); // Spotify Green
const Color _accentColor = Color(0xFF1ED760);
const Color _backgroundColor = Color(0xFF121212); // Dark background
const Color _cardColor = Color(0xFF282828);
const Color _textColor = Color(0xFFFFFFFF);
const Color _subTextColor = Color(0xFFB3B3B3);

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({super.key});

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  List<Map<String, dynamic>> songList = [];
  bool isLoading = true;
  String? errorMessage;
  int? _playingSongId;
  late final AudioPlayer _audioPlayer;
  int? _currentSongId;
  String? _currentSongUrl;

  @override
  void initState() {
    super.initState();
    fetchSongs();
    _audioPlayer = AudioPlayer();
    _audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        setState(() {
          _playingSongId = null;
        });
      }
    });
  }

  // Improved Progress Bar Loading (Optimization Suggestion)
  // The 'loading time' is the time taken by fetchSongs.
  // To make the loading *feel* faster:
  // 1. Ensure the API response is fast (server-side optimization).
  // 2. Reduce the data payload (ask the API to return less data initially).
  // 3. Implement aggressive pre-caching (already using CachedNetworkImage).
  // 4. Use Shimmer effect while loading to look more modern than a spinner.
  Future<void> fetchSongs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final uri = Uri.parse(musicListUrl);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> songItems = data['results'];

        // Introduce a small artificial delay (e.g., 500ms) here ONLY
        // if the API is *too* fast, to prevent a jarring "flash" of the list.
        // DO NOT use this if your API is slow. (Keep commented out in production)
        // await Future.delayed(const Duration(milliseconds: 500));

        setState(() {
          songList = songItems.map((item) {
            final artistImage = item['artist']['image'] as String?;
            final isRelativePath =
                artistImage != null && !artistImage.startsWith('http');

            return {
              'id': item['id'],
              'title': item['title']?.toString() ?? 'Untitled Song',
              'artist_name':
                  item['artist']['name']?.toString() ?? 'Unknown Artist',
              'duration': item['duration_formatted']?.toString() ?? '0:00',
              'audio_url': item['audio_file']?.toString(),
              'image_url':
                  isRelativePath ? "$baseUrl$artistImage" : artistImage,
              'release_date':
                  item['release_date']?.toString() ?? 'No Date Available',
            };
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Failed to load music list: Server returned status ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        errorMessage = 'Error fetching music list: $error';
        isLoading = false;
      });
    }
  }

  void _handlePlayPause(Map<String, dynamic> song) async {
    final int songId = song['id'];
    final String? audioUrl = song['audio_url'];

    if (audioUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Audio file not available for this song.')),
      );
      return;
    }

    try {
      if (_playingSongId == songId) {
        await _audioPlayer.pause();
        setState(() {
          _playingSongId = null;
        });
        return;
      }

      if (_currentSongId == songId && _currentSongUrl != null) {
        try {
          await _audioPlayer.play();
          setState(() => _playingSongId = songId);
          return;
        } catch (e) {
          debugPrint('Resume failed, will reload URL: $e');
        }
      }

      await _audioPlayer.stop();
      _currentSongId = songId;
      _currentSongUrl = audioUrl;
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
      setState(() {
        _playingSongId = songId;
      });

      // Show temporary feedback (modern designs often omit this for player bar feedback)
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Playing: ${song['title']}')),
      // );
    } catch (e) {
      debugPrint('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play audio.')),
      );
    }
  }

  String _formatDate(String dateString) {
    try {
      final DateTime dateTime = DateTime.parse(dateString);
      return DateFormat.yMMMd(Localizations.localeOf(context).toString())
          .format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? localizations = AppLocalizations.of(context);

    // Modern App Theme
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        primaryColor: _primaryColor,
        scaffoldBackgroundColor: const Color.fromARGB(255, 117, 117, 117),
        appBarTheme: const AppBarTheme(
          backgroundColor:
              Color.fromARGB(0, 2, 71, 7), // Transparent for modern look
          elevation: 0,
          foregroundColor: _textColor,
          titleTextStyle: TextStyle(
              color: _textColor, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        // Use a slight accent color for the progress indicators
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: _accentColor),
        // Slider theme for the bottom player
        sliderTheme: SliderThemeData(
          overlayColor: _accentColor.withOpacity(0.2),
          activeTrackColor: _accentColor,
          inactiveTrackColor: _subTextColor.withOpacity(0.3),
          thumbColor: _textColor,
          trackHeight: 2.0, // Make the track thinner
        ),
        iconTheme: const IconThemeData(color: _textColor),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 0, 73, 110),
          title: Text('مختارات من ذاكرة الإذاعة'),
          centerTitle: false, // Modern UIs often align titles left
        ),
        // Use the modern theme's background color
        body: buildBody(localizations),
        bottomNavigationBar: _buildBottomPlayerBar(),
      ),
    );
  }

  // MODERN DESIGN: Refactor and simplify the bottom player bar
  Widget _buildBottomPlayerBar() {
    final int? showId = _currentSongId ?? _playingSongId;
    if (showId == null) return const SizedBox.shrink();

    final Map<String, dynamic> song = songList.firstWhere(
      (s) => s['id'] == showId,
      orElse: () => {
        'title': 'Now Playing',
        'artist_name': '',
        'image_url': null,
      },
    );

    // StreamBuilder for a simplified player state and progress
    return StreamBuilder<PlayerState>(
      stream: _audioPlayer.playerStateStream,
      builder: (context, playerSnap) {
        final PlayerState playerState =
            playerSnap.data ?? PlayerState(false, ProcessingState.idle);
        final bool isPlaying = playerState.playing;

        return SafeArea(
          child: Container(
            height: 72, // Reduced height for a more compact design
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 1, 117, 17),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                    color: Color.fromARGB(66, 0, 164, 77),
                    blurRadius: 8,
                    offset: Offset(0, 4))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Simplified Progress Bar (LinearProgressIndicator) - Fixes design error of complex slider taking too much vertical space
                StreamBuilder<Duration?>(
                  stream: _audioPlayer.positionStream,
                  builder: (context, positionSnap) {
                    final Duration position =
                        positionSnap.data ?? Duration.zero;
                    final Duration duration =
                        _audioPlayer.duration ?? Duration.zero;
                    final double progress = (duration > Duration.zero)
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;

                    return LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color.fromARGB(255, 1, 116, 104),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_accentColor),
                      minHeight: 2, // Thinner progress bar
                    );
                  },
                ),
                // Controls Row
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Album Art (Small)
                        SizedBox(
                          width: 60,
                          height: 40,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: song['image_url'] != null
                                ? CachedNetworkImage(
                                    imageUrl: song['image_url']!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                        color: _subTextColor.withOpacity(0.1)),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.music_note,
                                            color: _subTextColor, size: 20),
                                  )
                                : const Icon(Icons.music_note,
                                    color: _subTextColor, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(song['title']?.toString() ?? 'Now Playing',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _textColor),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(song['artist_name']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontSize: 12, color: _subTextColor),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Play/Pause
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 32,
                            color: _textColor,
                            icon: Icon(isPlaying
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline),
                            onPressed: () {
                              if (_currentSongId != null) {
                                _handlePlayPause({
                                  'id': _currentSongId,
                                  'audio_url': _currentSongUrl,
                                  'title': song['title']
                                });
                              }
                            },
                          ),
                        ),
                        // Stop button removed for modern, minimalist design
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildBody(AppLocalizations? localizations) {
    if (isLoading) {
      // Modern: Use a simple, centered spinner on the dark background
      return const Center(
        child: CircularProgressIndicator(color: _accentColor),
      );
    } else if (errorMessage != null) {
      return Center(
        child: Text(
          localizations?.errorLoadingNews ?? 'Error Loading Songs',
          style: const TextStyle(color: _subTextColor),
        ),
      );
    } else if (songList.isEmpty) {
      return Center(
        child: Text(
          localizations?.noNewsAvailable ?? 'No Songs Available',
          style: const TextStyle(color: _subTextColor),
        ),
      );
    } else {
      return ListView.builder(
        itemCount: songList.length,
        itemBuilder: (context, index) {
          final song = songList[index];
          final bool isPlaying = _playingSongId == song['id'];

          return SongListItem(
            song: song,
            isPlaying: isPlaying,
            onPlayPause: () => _handlePlayPause(song),
            formatDate: _formatDate,
            onTap: () {
              // Handle navigation here
            },
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

// New Widget: SongListItem - Modernized Design
class SongListItem extends StatelessWidget {
  final Map<String, dynamic> song;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final Function(String) formatDate;
  final VoidCallback onTap;

  const SongListItem({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.onPlayPause,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Modern: Use less padding, sleeker card.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        color: const Color.fromARGB(255, 2, 91, 15),
        elevation: isPlaying ? 8 : 4, // Higher elevation when playing
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Slightly less rounded
          side: isPlaying
              ? const BorderSide(color: _accentColor, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Album/Artist Image
                _buildAlbumArt(song['image_url'], isPlaying),
                const SizedBox(width: 16),

                // Song Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song['title']!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isPlaying ? _accentColor : _textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song['artist_name']!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _subTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatDate(song['release_date']!)} • ${song['duration']}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Play/Pause Handler Button
                IconButton(
                  iconSize: 32,
                  color: isPlaying ? _accentColor : _subTextColor,
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                  ),
                  onPressed: onPlayPause,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArt(String? imageUrl, bool isPlaying) {
    const double size = 50; // Fixed small size for modern list item
    final double borderRadius =
        isPlaying ? 25 : 4; // Circle when playing, square when not

    Widget imageWidget;
    if (imageUrl != null) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: _subTextColor.withOpacity(0.1),
          child: const Center(
              child: Icon(Icons.music_note, color: _subTextColor, size: 20)),
        ),
        errorWidget: (context, url, error) =>
            const Icon(Icons.music_note, color: _subTextColor, size: 20),
      );
    } else {
      imageWidget =
          const Icon(Icons.music_note, color: _subTextColor, size: 20);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _subTextColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: imageWidget),
    );
  }
}
