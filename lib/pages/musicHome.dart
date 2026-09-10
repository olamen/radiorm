import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
// Assuming 'musicListUrl' and 'baseUrl' are defined in const.dart
import 'package:radiomr/const.dart';
import 'package:radiomr/l10n/localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({super.key});

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  // Renamed from newsList to songList
  List<Map<String, dynamic>> songList = [];
  bool isLoading = true;
  String? errorMessage;
  // State to manage playback. null if nothing is playing.
  int? _playingSongId;
  // just_audio player instance
  late final AudioPlayer _audioPlayer;
  // Track currently loaded song (to avoid reloading URL on resume)
  int? _currentSongId;
  String? _currentSongUrl;

  @override
  void initState() {
    super.initState();
    // Renamed fetchNews to fetchSongs
    fetchSongs();
    // Initialize audio player and listen for completion to update UI
    _audioPlayer = AudioPlayer();
    _audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        setState(() {
          _playingSongId = null;
        });
      }
    });
  }

  // Renamed fetchNews to fetchSongs
  Future<void> fetchSongs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Use your Song List API URL
      final uri = Uri.parse(musicListUrl);
      print('Fetching data from: $musicListUrl');

      final response = await http.get(uri);

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Data structure changed from 'newsItems' to 'songs'
        final List<dynamic> songItems = data['results'];

        setState(() {
          songList = songItems.map((item) {
            // Map the song API fields to a more usable structure
            final artistImage = item['artist']['image'] != null
                ? item['artist']['image'] as String
                : null;
            final isRelativePath =
                artistImage != null && !artistImage.startsWith('http');

            return {
              'id': item['id'], // Crucial for identifying the song for playback
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
        print('Failed to load songs: ${response.statusCode}');
      }
    } catch (error, stackTrace) {
      setState(() {
        errorMessage = 'Error fetching music list: $error';
        isLoading = false;
      });
      print('Exception: $error');
      print('StackTrace: $stackTrace');
    }
  }

  // New handler for Play/Pause action
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
        // Pause the currently playing song
        await _audioPlayer.pause();
        setState(() {
          _playingSongId = null;
        });
        return;
      }

      // If the requested song is already loaded in the player and the
      // player is paused, simply resume instead of reloading the URL.
      if (_currentSongId == songId && _currentSongUrl != null) {
        try {
          await _audioPlayer.play();
          setState(() => _playingSongId = songId);
          return;
        } catch (e) {
          // fallthrough to reload below if resume fails
          debugPrint('Resume failed, will reload URL: $e');
        }
      }

      // Load and play the requested song
      await _audioPlayer.stop();
      _currentSongId = songId;
      _currentSongUrl = audioUrl;
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
      setState(() {
        _playingSongId = songId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playing: ${song['title']}')),
      );
    } catch (e) {
      debugPrint('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play audio: $e')),
      );
    }
  }

  // Helper to format the date string
  String _formatDate(String dateString) {
    try {
      final DateTime dateTime = DateTime.parse(dateString);
      // Use short format for a compact list view
      return DateFormat.yMMMd(Localizations.localeOf(context).toString())
          .format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        // Update the title for the music page
        title: Text('مختارات من ذاكرة الإذاعة'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: buildBody(localizations),
      // Bottom player bar: appears when a song is loaded or playing
      bottomNavigationBar: _buildBottomPlayerBar(),
    );
  }

  Widget _buildBottomPlayerBar() {
    // Show nothing if no song is loaded
    final int? showId = _currentSongId ?? _playingSongId;
    if (showId == null) return const SizedBox.shrink();

    // Find song metadata
    final Map<String, dynamic> song = songList.firstWhere(
      (s) => s['id'] == showId,
      orElse: () => {'title': 'Now Playing', 'artist_name': ''},
    );

    // Streams for position and buffered/duration
    return SafeArea(
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress slider and times
            StreamBuilder<Duration>(
              stream: _audioPlayer.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = _audioPlayer.duration ?? Duration.zero;
                String fmt(Duration d) =>
                    d.inMinutes.remainder(60).toString().padLeft(2, '0') +
                    ':' +
                    (d.inSeconds.remainder(60)).toString().padLeft(2, '0');

                return Column(
                  children: [
                    Slider(
                      value: position.inMilliseconds
                          .clamp(
                              0,
                              duration.inMilliseconds > 0
                                  ? duration.inMilliseconds
                                  : 1)
                          .toDouble(),
                      min: 0,
                      max: (duration.inMilliseconds > 0)
                          ? duration.inMilliseconds.toDouble()
                          : 1.0,
                      onChanged: (value) {
                        final pos = Duration(milliseconds: value.toInt());
                        _audioPlayer.seek(pos);
                      },
                    ),
                    Row(
                      children: [
                        Text(fmt(position),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[700])),
                        const Spacer(),
                        Text(duration > Duration.zero ? fmt(duration) : '--:--',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[700])),
                      ],
                    ),
                  ],
                );
              },
            ),

            // Controls row
            Row(
              children: [
                // Play/Pause
                StreamBuilder<PlayerState>(
                  stream: _audioPlayer.playerStateStream,
                  builder: (context, snap) {
                    final playing = snap.data?.playing ?? false;
                    return IconButton(
                      iconSize: 36,
                      color: Colors.green[700],
                      icon: Icon(playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled),
                      onPressed: () {
                        if (playing) {
                          _audioPlayer.pause();
                          setState(() {
                            _playingSongId = null;
                          });
                        } else {
                          // resume or play current
                          if (_currentSongUrl != null) {
                            _handlePlayPause({
                              'id': _currentSongId,
                              'audio_url': _currentSongUrl,
                              'title': song['title']
                            });
                          }
                        }
                      },
                    );
                  },
                ),

                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song['title']?.toString() ?? 'Now Playing',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(song['artist_name']?.toString() ?? '',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),

                // Stop button
                IconButton(
                  iconSize: 28,
                  color: Colors.grey[700],
                  icon: const Icon(Icons.stop),
                  onPressed: () async {
                    await _audioPlayer.stop();
                    setState(() {
                      _playingSongId = null;
                      _currentSongId = null;
                      _currentSongUrl = null;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBody(AppLocalizations? localizations) {
    // ... (Loading, Error, Empty list widgets remain similar,
    //      but updated to refer to 'Songs' instead of 'News') ...

    // Using a more concise structure for brevity,
    // keep your original Loading/Error/Empty logic but update the text.
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!)),
      );
    } else if (errorMessage != null) {
      return Center(
        child: Text(localizations?.errorLoadingNews ?? 'Error Loading Songs'),
      );
    } else if (songList.isEmpty) {
      return Center(
        child: Text(localizations?.noNewsAvailable ?? 'No Songs Available'),
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
            // Assuming you want to keep the tap for navigation (e.g., to a detail page)
            onTap: () {
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (_) => DetailSongPage(song: song), // Change to your detail song page
              //   ),
              // );
            },
          );
        },
      );
    }
  }

  // **[IMPORTANT]** Dispose of the audio player when the widget is removed
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

// New Widget: SongListItem

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        shadowColor: Colors.black12,
        color: isPlaying ? Colors.green.shade50 : Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap, // Tap to view details (optional)
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Album/Artist Image (bigger when playing)
                _buildAlbumArt(song['image_url'], isPlaying),
                const SizedBox(width: 12),

                // Song Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song['title']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song['artist_name']!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatDate(song['release_date']!)} | ${song['duration']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),

                // Play/Pause Handler Button
                IconButton(
                  iconSize: 32,
                  color: Colors.green[700],
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
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
    final double size = isPlaying ? 90 : 60;
    if (imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade200,
          ),
          child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.green[700]!))),
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade200,
          ),
          child: const Icon(Icons.music_note, color: Colors.grey),
        ),
      );
    } else {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade200,
        ),
        child: const Icon(Icons.music_note, color: Colors.grey),
      );
    }
  }
}
