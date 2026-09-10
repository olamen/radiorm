import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'youtube_webview_page.dart';

Future<bool> openYoutubeVideo(String videoId) async {
  final appUri = Uri.parse('youtube://www.youtube.com/watch?v=$videoId');
  final webUri = Uri.https('www.youtube.com', '/watch', {'v': videoId});

  try {
    if (await launchUrl(appUri, mode: LaunchMode.externalApplication)) {
      return true;
    }
  } catch (_) {
    // Fall through to the universal web URL when the app is unavailable.
  }

  try {
    return await launchUrl(webUri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

class YoutubePlaylistPage extends StatefulWidget {
  const YoutubePlaylistPage({super.key, this.playlistUrl});

  static const defaultPlaylistUrl =
      'https://www.youtube.com/playlist?list=PLgrDaum2zgmER_X1OKysYQ6iq-NfMBLpl';

  final String? playlistUrl;

  @override
  State<YoutubePlaylistPage> createState() => _YoutubePlaylistPageState();
}

class _YoutubePlaylistPageState extends State<YoutubePlaylistPage> {
  final List<YoutubeVideo> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _playlistTitle = 'YouTube Playlist';
  String? _playlistDescription;
  String _playlistCount = '';

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final playlistUrl =
          widget.playlistUrl ?? YoutubePlaylistPage.defaultPlaylistUrl;
      final response = await http.get(Uri.parse(playlistUrl));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final jsonString = _extractInitialData(response.body);
      if (jsonString == null) {
        throw Exception('Unable to extract playlist data from YouTube page');
      }

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final metadataRenderer = _findRenderer(data, 'playlistMetadataRenderer');
      if (metadataRenderer != null) {
        _playlistTitle =
            _extractText(metadataRenderer['title']) ?? _playlistTitle;
        _playlistDescription = _extractText(metadataRenderer['description']);
        _playlistCount = _extractText(metadataRenderer['videoCountText']) ?? '';
      }

      final contents = _findPlaylistContents(data);
      if (contents == null) {
        throw Exception('Playlist contents not found in YouTube response');
      }

      final videos = <YoutubeVideo>[];
      for (final item in contents) {
        if (item is Map<String, dynamic>) {
          final lockup = item['lockupViewModel'] as Map<String, dynamic>?;
          if (lockup == null) continue;

          final watchEndpoint = _findRenderer(lockup, 'watchEndpoint');
          final videoId = watchEndpoint?['videoId']?.toString() ??
              _findStringByKey(lockup, 'videoId');
          final title = _extractText(
                  lockup['metadata']?['lockupMetadataViewModel']?['title']) ??
              _extractText(
                  lockup['metadata']?['lockupMetadataViewModel']?['metadata']);
          final duration = _extractDurationFromLockup(lockup) ?? '';

          if (videoId != null && title != null) {
            final extractedThumbnail =
                _extractThumbnailUrl(lockup['contentImage']);
            final thumbnailUrl = extractedThumbnail.isNotEmpty
                ? extractedThumbnail
                : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
            videos.add(YoutubeVideo(
              videoId: videoId,
              title: title,
              author: '',
              duration: duration,
              thumbnailUrl: thumbnailUrl,
            ));
          }
        }
      }

      setState(() {
        _videos
          ..clear()
          ..addAll(videos);
        _playlistCount = _playlistCount.isNotEmpty
            ? _playlistCount
            : '${videos.length} videos';
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  String? _extractInitialData(String html) {
    final regex =
        RegExp(r'ytInitialData\s*=\s*({.*?});\s*</script>', dotAll: true);
    final match = regex.firstMatch(html);
    if (match != null) {
      return match.group(1);
    }

    final altRegex =
        RegExp(r'window\["ytInitialData"\]\s*=\s*({.*?});', dotAll: true);
    return altRegex.firstMatch(html)?.group(1);
  }

  Map<String, dynamic>? _findRenderer(dynamic node, String key) {
    if (node is Map<String, dynamic>) {
      if (node.containsKey(key)) {
        return node[key] as Map<String, dynamic>?;
      }
      for (final value in node.values) {
        final found = _findRenderer(value, key);
        if (found != null) {
          return found;
        }
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findRenderer(item, key);
        if (found != null) {
          return found;
        }
      }
    }
    return null;
  }

  List<dynamic>? _findPlaylistContents(Map<String, dynamic> data) {
    final contentsMap = data['contents'];
    if (contentsMap is! Map<String, dynamic>) {
      return null;
    }

    final twoColumn = contentsMap['twoColumnBrowseResultsRenderer'];
    if (twoColumn is! Map<String, dynamic>) {
      return null;
    }

    final tabs = twoColumn['tabs'];
    if (tabs is! List<dynamic> || tabs.isEmpty) {
      return null;
    }

    final firstTab = tabs[0];
    if (firstTab is! Map<String, dynamic>) {
      return null;
    }

    final tabRenderer = firstTab['tabRenderer'];
    if (tabRenderer is! Map<String, dynamic>) {
      return null;
    }

    final content = tabRenderer['content'];
    if (content is! Map<String, dynamic>) {
      return null;
    }

    final sectionList = content['sectionListRenderer'];
    if (sectionList is! Map<String, dynamic>) {
      return null;
    }

    final sectionContents = sectionList['contents'];
    if (sectionContents is! List<dynamic> || sectionContents.isEmpty) {
      return null;
    }

    final firstSection = sectionContents[0];
    if (firstSection is! Map<String, dynamic>) {
      return null;
    }

    final itemSection = firstSection['itemSectionRenderer'];
    if (itemSection is! Map<String, dynamic>) {
      return null;
    }

    final contents = itemSection['contents'];
    if (contents is! List<dynamic>) {
      return null;
    }

    return contents;
  }

  String? _extractText(dynamic node) {
    if (node is String) {
      return node;
    }
    if (node is Map<String, dynamic>) {
      if (node['simpleText'] is String) {
        return node['simpleText'] as String;
      }
      if (node['text'] is String) {
        return node['text'] as String;
      }
      if (node['content'] is String) {
        return node['content'] as String;
      }
      final runs = node['runs'] as List<dynamic>?;
      if (runs != null && runs.isNotEmpty) {
        return runs
            .map((run) =>
                run is Map<String, dynamic> ? run['text']?.toString() : null)
            .whereType<String>()
            .join();
      }
    } else if (node is List) {
      return node
          .map((item) => _extractText(item))
          .whereType<String>()
          .join(' ');
    }
    return null;
  }

  String _extractThumbnailUrl(dynamic thumbnailNode) {
    if (thumbnailNode is Map<String, dynamic>) {
      final imageSection = thumbnailNode['thumbnail'] ?? thumbnailNode['image'];
      if (imageSection is Map<String, dynamic>) {
        final sources = imageSection['sources'] as List<dynamic>?;
        if (sources != null && sources.isNotEmpty) {
          final last = sources.last as Map<String, dynamic>?;
          return last?['url']?.toString() ?? '';
        }
        final thumbnails = imageSection['thumbnails'] as List<dynamic>?;
        if (thumbnails != null && thumbnails.isNotEmpty) {
          final last = thumbnails.last as Map<String, dynamic>?;
          return last?['url']?.toString() ?? '';
        }
      }
      final thumbnails = thumbnailNode['thumbnails'] as List<dynamic>?;
      if (thumbnails != null && thumbnails.isNotEmpty) {
        final last = thumbnails.last as Map<String, dynamic>?;
        return last?['url']?.toString() ?? '';
      }
    }
    return '';
  }

  String? _findStringByKey(dynamic node, String key) {
    if (node is Map<String, dynamic>) {
      if (node.containsKey(key) && node[key] is String) {
        return node[key] as String;
      }
      for (final value in node.values) {
        final found = _findStringByKey(value, key);
        if (found != null) {
          return found;
        }
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findStringByKey(item, key);
        if (found != null) {
          return found;
        }
      }
    }
    return null;
  }

  String? _extractDurationFromLockup(Map<String, dynamic> lockup) {
    final overlays = lockup['contentImage'] is Map<String, dynamic>
        ? lockup['contentImage']['thumbnailViewModel'] is Map<String, dynamic>
            ? lockup['contentImage']['thumbnailViewModel']['overlays']
                as List<dynamic>?
            : null
        : null;
    if (overlays == null) return null;
    for (final overlay in overlays) {
      if (overlay is Map<String, dynamic>) {
        final bottom =
            overlay['thumbnailBottomOverlayViewModel'] as Map<String, dynamic>?;
        final badges = bottom?['badges'] as List<dynamic>?;
        if (badges == null) continue;
        for (final badge in badges) {
          final textNode = badge is Map<String, dynamic>
              ? badge['thumbnailBadgeViewModel'] as Map<String, dynamic>?
              : null;
          final text = _extractText(textNode?['text']);
          if (text != null && text.contains(':')) {
            return text;
          }
        }
      }
    }
    return null;
  }

  Future<void> _openVideo(YoutubeVideo video) async {
    final relatedVideos = _videos
        .where((item) => item.videoId != video.videoId)
        .take(15)
        .map(
          (item) => YoutubeRelatedVideo(
            videoId: item.videoId,
            title: item.title,
            thumbnailUrl: item.thumbnailUrl,
          ),
        )
        .toList();
    final url = Uri.https(
      'www.youtube.com',
      '/watch',
      {'v': video.videoId},
    ).toString();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YoutubeWebViewPage(
          url: url,
          title: video.title,
          videoId: video.videoId,
          relatedVideos: relatedVideos,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Playlist'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _playlistTitle,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _playlistCount.isNotEmpty
                        ? _playlistCount
                        : 'Loading video count...',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  if (_playlistDescription != null &&
                      _playlistDescription!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _playlistDescription!,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final playlistUrl = widget.playlistUrl ??
                          YoutubePlaylistPage.defaultPlaylistUrl;
                      final uri = Uri.parse(playlistUrl);
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.playlist_play),
                    label: const Text('Open playlist in YouTube'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPlaylist,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_videos.isEmpty) {
      return const Center(child: Text('No videos found in this playlist.'));
    }
    return ListView.separated(
      itemCount: _videos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final video = _videos[index];
        return Card(
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openVideo(video),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: 120,
                    height: 90,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 120,
                      height: 90,
                      color: Colors.grey.shade200,
                      child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 120,
                      height: 90,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          video.author.isNotEmpty ? video.author : 'YouTube',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          video.duration.isNotEmpty
                              ? video.duration
                              : 'Unknown duration',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.play_circle_outline,
                      color: Colors.green, size: 28),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class YoutubeVideoPlayerPage extends StatefulWidget {
  final String initialVideoId;
  final List<String> playlistIds;
  final String title;

  const YoutubeVideoPlayerPage({
    super.key,
    required this.initialVideoId,
    required this.playlistIds,
    required this.title,
  });

  @override
  State<YoutubeVideoPlayerPage> createState() => _YoutubeVideoPlayerPageState();
}

class _YoutubeVideoPlayerPageState extends State<YoutubeVideoPlayerPage> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubePlayerValue>? _subscription;
  String? _errorMessage;
  AudioHandler? _audioHandler;
  bool _wasRadioPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.initialVideoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        enableJavaScript: true,
      ),
    );

    if (widget.playlistIds.length > 1) {
      _controller.loadPlaylist(
        list: widget.playlistIds,
        index: widget.playlistIds.indexOf(widget.initialVideoId),
      );
    }

    _subscription = _controller.stream.listen((value) {
      if (value.hasError) {
        setState(() {
          _errorMessage = _youtubeErrorMessage(value.error);
        });
      }
    }, onError: (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    });

    // The background radio stream holds an exclusive
    // AVAudioSessionCategory.playback session on iOS, which can prevent the
    // embedded YouTube video's audio/playback from initializing correctly on
    // real devices. Pause it while the video player is open and resume it
    // (if it was playing) once this page closes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final audioHandler = Provider.of<AudioHandler>(context, listen: false);
      _audioHandler = audioHandler;
      _wasRadioPlaying = audioHandler.playbackState.value.playing;
      if (_wasRadioPlaying) {
        audioHandler.pause();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
    if (_wasRadioPlaying) {
      _audioHandler?.play();
    }
    super.dispose();
  }

  Future<void> _openInYouTube() async {
    final appUri = Uri.parse(
      'youtube://www.youtube.com/watch?v=${widget.initialVideoId}',
    );
    final webUri = Uri.https(
      'www.youtube.com',
      '/watch',
      {'v': widget.initialVideoId},
    );

    final opened =
        await launchUrl(appUri, mode: LaunchMode.externalApplication) ||
            await launchUrl(webUri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open YouTube.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                YoutubePlayer(controller: _controller),
                if (_errorMessage != null)
                  Container(
                    color: Colors.black.withOpacity(0.65),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.white),
                            const SizedBox(height: 16),
                            Text(
                              'Playback failed. Open the video in YouTube to continue.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open in YouTube'),
                              onPressed: _openInYouTube,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Now playing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.title,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _youtubeErrorMessage(YoutubeError error) {
    switch (error) {
      case YoutubeError.invalidParam:
        return 'This video cannot be played here.';
      case YoutubeError.html5Error:
        return 'The video cannot be played by the HTML5 player.';
      case YoutubeError.videoNotFound:
        return 'This video was removed or is private.';
      case YoutubeError.notEmbeddable:
      case YoutubeError.sameAsNotEmbeddable:
        return 'This video is not embeddable. Open it in YouTube instead.';
      case YoutubeError.unknown:
      default:
        return 'Playback failed. Open the video in YouTube to continue.';
    }
  }
}

class YoutubeVideo {
  final String videoId;
  final String title;
  final String author;
  final String duration;
  final String thumbnailUrl;

  YoutubeVideo({
    required this.videoId,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
  });
}
