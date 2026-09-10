import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../const.dart';
import 'youtube_playlist_page.dart';
import 'youtube_webview_page.dart';

/// Browses a YouTube channel: its playlists and its latest uploaded videos.
///
/// This scrapes the channel's public "Videos" and "Playlists" tab pages
/// (like [YoutubePlaylistPage] does for a single playlist) since there is
/// no official YouTube Data API key configured in this app. As with that
/// page, this depends on YouTube's internal page structure and can break
/// if YouTube changes it.
class YoutubeChannelPage extends StatefulWidget {
  const YoutubeChannelPage({super.key, this.channelUrl});

  final String? channelUrl;

  @override
  State<YoutubeChannelPage> createState() => _YoutubeChannelPageState();
}

class _YoutubeChannelPageState extends State<YoutubeChannelPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String get _channelUrl {
    final url = widget.channelUrl ?? youtubeChannelUrl;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قناة اليوتيوب'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'أحدث الفيديوهات'),
            Tab(text: 'قوائم التشغيل'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ChannelVideosTab(channelUrl: _channelUrl),
          _ChannelPlaylistsTab(channelUrl: _channelUrl),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared YouTube page-scraping helpers
// ---------------------------------------------------------------------------

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

/// Recursively finds the first value for [key] anywhere under [node].
dynamic _findFirst(dynamic node, String key) {
  if (node is Map) {
    if (node.containsKey(key)) {
      return node[key];
    }
    for (final value in node.values) {
      final found = _findFirst(value, key);
      if (found != null) return found;
    }
  } else if (node is List) {
    for (final item in node) {
      final found = _findFirst(item, key);
      if (found != null) return found;
    }
  }
  return null;
}

String? _extractText(dynamic node) {
  if (node is String) return node;
  if (node is Map) {
    if (node['content'] is String) return node['content'] as String;
    if (node['simpleText'] is String) return node['simpleText'] as String;
    if (node['text'] is String) return node['text'] as String;
    final runs = node['runs'] as List<dynamic>?;
    if (runs != null && runs.isNotEmpty) {
      return runs
          .map((run) => run is Map ? run['text']?.toString() : null)
          .whereType<String>()
          .join();
    }
  }
  return null;
}

String _extractThumbnailUrl(dynamic lockup) {
  final sources = _findFirst(lockup, 'sources') as List<dynamic>?;
  if (sources == null || sources.isEmpty) return '';
  final last = sources.last as Map<String, dynamic>?;
  return last?['url']?.toString() ?? '';
}

String? _extractDuration(dynamic lockup) {
  final overlays = _findFirst(lockup, 'overlays') as List<dynamic>?;
  if (overlays == null) return null;
  for (final overlay in overlays) {
    final bottom = (overlay is Map)
        ? overlay['thumbnailBottomOverlayViewModel'] as Map<String, dynamic>?
        : null;
    final badges = bottom?['badges'] as List<dynamic>?;
    if (badges == null) continue;
    for (final badge in badges) {
      final tb = (badge is Map)
          ? badge['thumbnailBadgeViewModel'] as Map<String, dynamic>?
          : null;
      final text = tb?['text'];
      if (text is String && text.contains(':')) return text;
    }
  }
  return null;
}

Map<String, dynamic>? _findSelectedTabContent(Map<String, dynamic> data) {
  final tabs = _findFirst(data, 'tabs') as List<dynamic>?;
  if (tabs == null) return null;
  for (final tab in tabs) {
    final tr =
        (tab is Map) ? tab['tabRenderer'] as Map<String, dynamic>? : null;
    if (tr != null && tr['selected'] == true) {
      return tr['content'] as Map<String, dynamic>?;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// "Load more" pagination helpers.
//
// The channel's Videos/Playlists tabs only render an initial batch of
// items. The remaining items are fetched on demand from YouTube's internal
// `browse` endpoint using a continuation token embedded as a trailing
// `continuationItemRenderer` entry in the items list.
// ---------------------------------------------------------------------------

String? _extractApiKey(String html) {
  return RegExp(r'"INNERTUBE_API_KEY"\s*:\s*"([^"]+)"')
      .firstMatch(html)
      ?.group(1);
}

String? _extractClientVersion(String html) {
  return RegExp(r'"clientVersion"\s*:\s*"([\d.]+)"').firstMatch(html)?.group(1);
}

/// Finds the trailing continuation token in a list of tab/grid items (or a
/// continuation response's appended items).
String? _extractContinuationToken(List<dynamic> items) {
  for (final item in items) {
    final renderer = (item is Map)
        ? item['continuationItemRenderer'] as Map<String, dynamic>?
        : null;
    final token = renderer?['continuationEndpoint']?['continuationCommand']
        ?['token'] as String?;
    if (token != null) return token;
  }
  return null;
}

/// Fetches the next page of items for a continuation [token].
Future<Map<String, dynamic>?> _fetchContinuation({
  required String apiKey,
  required String clientVersion,
  required String token,
}) async {
  final uri =
      Uri.parse('https://www.youtube.com/youtubei/v1/browse?key=$apiKey');
  final response = await http.post(
    uri,
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({
      'context': {
        'client': {
          'clientName': 'WEB',
          'clientVersion': clientVersion,
          'hl': 'ar',
          'gl': 'US',
        },
      },
      'continuation': token,
    }),
  );
  if (response.statusCode != 200) return null;
  return jsonDecode(response.body) as Map<String, dynamic>;
}

/// Extracts the appended items list from a continuation response.
List<dynamic> _continuationItems(Map<String, dynamic> response) {
  final actions = response['onResponseReceivedActions'] as List<dynamic>?;
  if (actions != null) {
    for (final action in actions) {
      final append = (action is Map)
          ? action['appendContinuationItemsAction'] as Map<String, dynamic>?
          : null;
      final items = append?['continuationItems'] as List<dynamic>?;
      if (items != null) return items;
    }
  }
  final fallback = _findFirst(response, 'continuationItems') as List<dynamic>?;
  return fallback ?? const [];
}

/// Parses an Arabic relative-time string (e.g. "قبل 3 أيام", "قبل أسبوعين")
/// into an approximate number of days ago. Returns null if unrecognized.
int? _parseDaysAgo(String text) {
  final t = text.trim();
  if (!t.contains('قبل')) return null;

  if (t.contains('لحظ') ||
      t.contains('دقيق') ||
      t.contains('ثان') ||
      t.contains('ساع')) {
    return 0;
  }

  int? number() => int.tryParse(RegExp(r'\d+').firstMatch(t)?.group(0) ?? '');

  // Arabic singular/dual/plural forms don't always share a common
  // substring (e.g. "يوم" vs "أيام", "سنة" vs "سنتين"/"سنوات"), so each
  // unit checks all of its known forms explicitly.
  final isDay = t.contains('يوم') || t.contains('أيام') || t.contains('ايام');
  final isWeek = t.contains('أسبوع') ||
      t.contains('اسبوع') ||
      t.contains('أسابيع') ||
      t.contains('اسابيع');
  final isMonth = t.contains('شهر') || t.contains('أشهر') || t.contains('اشهر');
  final isYear = t.contains('سنة') ||
      t.contains('سنت') ||
      t.contains('سنوات') ||
      t.contains('عام') ||
      t.contains('أعوام') ||
      t.contains('اعوام');

  if (isDay) {
    if (t.contains('يومين')) return 2;
    if (t.contains('يوم واحد')) return 1;
    return number() ?? 1;
  }
  if (isWeek) {
    if (t.contains('أسبوعين') || t.contains('اسبوعين')) return 14;
    return (number() ?? 1) * 7;
  }
  if (isMonth) {
    if (t.contains('شهرين')) return 60;
    return (number() ?? 1) * 30;
  }
  if (isYear) {
    if (t.contains('سنتين') || t.contains('عامين')) return 730;
    return (number() ?? 1) * 365;
  }
  return null;
}

/// Simple, single-select date range used to filter the videos list.
enum _DateFilter { all, today, week, month, year }

extension on _DateFilter {
  String get label {
    switch (this) {
      case _DateFilter.all:
        return 'الكل';
      case _DateFilter.today:
        return 'اليوم';
      case _DateFilter.week:
        return 'هذا الأسبوع';
      case _DateFilter.month:
        return 'هذا الشهر';
      case _DateFilter.year:
        return 'هذه السنة';
    }
  }

  bool matches(int? daysAgo) {
    if (this == _DateFilter.all) return true;
    if (daysAgo == null) return false;
    switch (this) {
      case _DateFilter.all:
        return true;
      case _DateFilter.today:
        return daysAgo <= 1;
      case _DateFilter.week:
        return daysAgo <= 7;
      case _DateFilter.month:
        return daysAgo <= 30;
      case _DateFilter.year:
        return daysAgo <= 365;
    }
  }
}

/// Display order for the videos list: newest-first (descending by date,
/// the default) or oldest-first (ascending by date).
enum _SortOrder { newest, oldest }

extension on _SortOrder {
  String get label {
    switch (this) {
      case _SortOrder.newest:
        return 'الأحدث أولاً';
      case _SortOrder.oldest:
        return 'الأقدم أولاً';
    }
  }

  IconData get icon {
    switch (this) {
      case _SortOrder.newest:
        return Icons.arrow_downward;
      case _SortOrder.oldest:
        return Icons.arrow_upward;
    }
  }
}

// ---------------------------------------------------------------------------
// Videos tab
// ---------------------------------------------------------------------------

class _ChannelVideo {
  _ChannelVideo({
    required this.videoId,
    required this.title,
    required this.duration,
    required this.viewsText,
    required this.timeText,
    required this.daysAgo,
    required this.thumbnailUrl,
  });

  final String videoId;
  final String title;
  final String duration;
  final String viewsText;
  final String timeText;
  final int? daysAgo;
  final String thumbnailUrl;

  String get meta {
    return [viewsText, timeText].where((s) => s.isNotEmpty).join(' • ');
  }
}

class _ChannelVideosTab extends StatefulWidget {
  const _ChannelVideosTab({required this.channelUrl});

  final String channelUrl;

  @override
  State<_ChannelVideosTab> createState() => _ChannelVideosTabState();
}

class _ChannelVideosTabState extends State<_ChannelVideosTab> {
  final List<_ChannelVideo> _videos = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String? _continuationToken;
  String? _apiKey;
  String? _clientVersion;
  String _searchQuery = '';
  _DateFilter _dateFilter = _DateFilter.all;
  _SortOrder _sortOrder = _SortOrder.newest;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isFiltering =>
      _searchQuery.isNotEmpty || _dateFilter != _DateFilter.all;

  bool _matchesFilters(_ChannelVideo video) {
    if (_searchQuery.isNotEmpty &&
        !video.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
      return false;
    }
    return _dateFilter.matches(video.daysAgo);
  }

  List<_ChannelVideo> get _filteredVideos {
    if (!_isFiltering) return _videos;
    return _videos.where(_matchesFilters).toList();
  }

  /// The list to render: filtered, then ordered newest-first or
  /// oldest-first. The channel's "Videos" page is fetched newest-first by
  /// default, so "oldest" is simply the reverse of that order.
  List<_ChannelVideo> get _displayedVideos {
    final filtered = _filteredVideos;
    if (_sortOrder == _SortOrder.newest) return filtered;
    return filtered.reversed.toList();
  }

  List<_ChannelVideo> _parseVideoItems(List<dynamic> items) {
    final videos = <_ChannelVideo>[];
    for (final item in items) {
      final lockup = (item is Map)
          ? _findFirst(item, 'lockupViewModel') as Map<String, dynamic>?
          : null;
      if (lockup == null) continue;
      if (lockup['contentType'] != 'LOCKUP_CONTENT_TYPE_VIDEO') continue;

      final videoId = lockup['contentId'] as String?;
      final title = _extractText(
          lockup['metadata']?['lockupMetadataViewModel']?['title']);
      if (videoId == null || title == null) continue;

      final cm = _findFirst(lockup, 'contentMetadataViewModel')
          as Map<String, dynamic>?;
      final rows = cm?['metadataRows'] as List<dynamic>? ?? [];
      final metaParts = <String>[];
      for (final row in rows) {
        final parts =
            (row is Map) ? row['metadataParts'] as List<dynamic>? : null;
        for (final part in parts ?? <dynamic>[]) {
          final text = _extractText((part is Map) ? part['text'] : null);
          if (text != null && text.isNotEmpty) metaParts.add(text);
        }
      }

      final viewsText = metaParts.firstWhere((part) => part.contains('مشاهد'),
          orElse: () => '');
      final timeText = metaParts.firstWhere((part) => part.contains('قبل'),
          orElse: () => '');

      videos.add(_ChannelVideo(
        videoId: videoId,
        title: title,
        duration: _extractDuration(lockup) ?? '',
        viewsText: viewsText,
        timeText: timeText,
        daysAgo: timeText.isEmpty ? null : _parseDaysAgo(timeText),
        thumbnailUrl: _extractThumbnailUrl(lockup),
      ));
    }
    return videos;
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response =
          await http.get(Uri.parse('${widget.channelUrl}/videos?hl=ar'));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final jsonString = _extractInitialData(response.body);
      if (jsonString == null) {
        throw Exception('Unable to extract channel data from YouTube page');
      }
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final tabContent = _findSelectedTabContent(data);
      final richGrid =
          _findFirst(tabContent, 'richGridRenderer') as Map<String, dynamic>?;
      final contents = richGrid?['contents'] as List<dynamic>? ?? [];

      final videos = _parseVideoItems(contents);

      setState(() {
        _videos
          ..clear()
          ..addAll(videos);
        _apiKey = _extractApiKey(response.body);
        _clientVersion = _extractClientVersion(response.body);
        _continuationToken = _extractContinuationToken(contents);
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  /// Fetches more videos. When a search/date filter is active, keeps
  /// fetching subsequent pages automatically (up to a safety cap) until a
  /// newly-fetched page contains at least one match, or there are no more
  /// pages — instead of requiring the user to tap repeatedly for a single
  /// page that may contain zero matches.
  Future<void> _loadMore() async {
    final apiKey = _apiKey;
    final clientVersion = _clientVersion;
    if (apiKey == null || clientVersion == null) return;
    if (_isLoadingMore || _continuationToken == null) return;

    setState(() => _isLoadingMore = true);
    final isFiltering = _isFiltering;
    const maxHops = 15;
    var hops = 0;
    try {
      while (_continuationToken != null && hops < maxHops) {
        hops++;
        final response = await _fetchContinuation(
          apiKey: apiKey,
          clientVersion: clientVersion,
          token: _continuationToken!,
        );
        if (response == null) {
          throw Exception('تعذر تحميل المزيد من الفيديوهات');
        }
        final items = _continuationItems(response);
        final videos = _parseVideoItems(items);
        final matchedCount = videos.where(_matchesFilters).length;

        _videos.addAll(videos);
        _continuationToken = _extractContinuationToken(items);

        if (!isFiltering || matchedCount > 0) break;
      }
      setState(() => _isLoadingMore = false);
    } catch (error) {
      setState(() => _isLoadingMore = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _openVideo(_ChannelVideo video) async {
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

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: TextField(
        controller: _searchController,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: 'ابحث في الفيديوهات...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _searchController.clear,
                ),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildDateFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _DateFilter.values.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _DateFilter.values[index];
                  final selected = _dateFilter == filter;
                  return ChoiceChip(
                    label: Text(filter.label),
                    selected: selected,
                    onSelected: (_) => setState(() => _dateFilter = filter),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildSortToggleButton(),
        ],
      ),
    );
  }

  Widget _buildSortToggleButton() {
    return Tooltip(
      message: _sortOrder.label,
      child: IconButton.filledTonal(
        onPressed: () {
          setState(() {
            _sortOrder = _sortOrder == _SortOrder.newest
                ? _SortOrder.oldest
                : _SortOrder.newest;
          });
        },
        icon: Icon(_sortOrder.icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    if (_videos.isEmpty) {
      return const Center(child: Text('لا توجد فيديوهات.'));
    }

    final filtered = _displayedVideos;
    final showLoadMore = _continuationToken != null;
    final hasNoMatches = filtered.isEmpty;

    return Column(
      children: [
        _buildSearchField(),
        _buildDateFilterChips(),
        Expanded(
          child: hasNoMatches && !showLoadMore
              ? const Center(child: Text('لا توجد نتائج مطابقة.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: (hasNoMatches ? 1 : filtered.length) +
                        (showLoadMore ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (hasNoMatches && index == 0) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                                'لا توجد نتائج مطابقة ضمن الفيديوهات المحمّلة.'),
                          ),
                        );
                      }
                      final itemIndex = hasNoMatches ? index - 1 : index;
                      if (itemIndex >= filtered.length) {
                        return Center(
                          child: _isLoadingMore
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(),
                                )
                              : OutlinedButton.icon(
                                  onPressed: _loadMore,
                                  icon: const Icon(Icons.expand_more),
                                  label: const Text('تحميل المزيد'),
                                ),
                        );
                      }
                      final video = filtered[itemIndex];
                      return Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openVideo(video),
                          child: Row(
                            children: [
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
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    width: 120,
                                    height: 90,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.grey),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        video.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      if (video.meta.isNotEmpty)
                                        Text(
                                          video.meta,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54),
                                        ),
                                      const SizedBox(height: 6),
                                      if (video.duration.isNotEmpty)
                                        Text(
                                          video.duration,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black45),
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
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Playlists tab
// ---------------------------------------------------------------------------

class _ChannelPlaylist {
  _ChannelPlaylist({
    required this.playlistId,
    required this.title,
    required this.videoCount,
    required this.thumbnailUrl,
  });

  final String playlistId;
  final String title;
  final String videoCount;
  final String thumbnailUrl;
}

class _ChannelPlaylistsTab extends StatefulWidget {
  const _ChannelPlaylistsTab({required this.channelUrl});

  final String channelUrl;

  @override
  State<_ChannelPlaylistsTab> createState() => _ChannelPlaylistsTabState();
}

class _ChannelPlaylistsTabState extends State<_ChannelPlaylistsTab> {
  final List<_ChannelPlaylist> _playlists = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String? _continuationToken;
  String? _apiKey;
  String? _clientVersion;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ChannelPlaylist> get _filteredPlaylists {
    if (_searchQuery.isEmpty) return _playlists;
    final query = _searchQuery.toLowerCase();
    return _playlists
        .where((playlist) => playlist.title.toLowerCase().contains(query))
        .toList();
  }

  bool _matchesFilters(_ChannelPlaylist playlist) {
    if (_searchQuery.isEmpty) return true;
    return playlist.title.toLowerCase().contains(_searchQuery.toLowerCase());
  }

  List<_ChannelPlaylist> _parsePlaylistItems(List<dynamic> items) {
    final playlists = <_ChannelPlaylist>[];
    for (final item in items) {
      final lockup = (item is Map)
          ? _findFirst(item, 'lockupViewModel') as Map<String, dynamic>?
          : null;
      if (lockup == null) continue;
      if (lockup['contentType'] != 'LOCKUP_CONTENT_TYPE_PLAYLIST') continue;

      final playlistId = lockup['contentId'] as String?;
      final title = _extractText(
          lockup['metadata']?['lockupMetadataViewModel']?['title']);
      if (playlistId == null || title == null) continue;

      final badgeVm = _findFirst(lockup, 'thumbnailOverlayBadgeViewModel')
          as Map<String, dynamic>?;
      final badges = badgeVm?['thumbnailBadges'] as List<dynamic>?;
      String videoCount = '';
      if (badges != null) {
        for (final badge in badges) {
          final tb = (badge is Map)
              ? badge['thumbnailBadgeViewModel'] as Map<String, dynamic>?
              : null;
          final text = tb?['text'];
          if (text is String) {
            videoCount = text;
            break;
          }
        }
      }

      playlists.add(_ChannelPlaylist(
        playlistId: playlistId,
        title: title,
        videoCount: videoCount,
        thumbnailUrl: _extractThumbnailUrl(lockup),
      ));
    }
    return playlists;
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response =
          await http.get(Uri.parse('${widget.channelUrl}/playlists?hl=ar'));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final jsonString = _extractInitialData(response.body);
      if (jsonString == null) {
        throw Exception('Unable to extract channel data from YouTube page');
      }
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final tabContent = _findSelectedTabContent(data);
      final gridRenderer =
          _findFirst(tabContent, 'gridRenderer') as Map<String, dynamic>?;
      final items = gridRenderer?['items'] as List<dynamic>? ?? [];

      final playlists = _parsePlaylistItems(items);

      setState(() {
        _playlists
          ..clear()
          ..addAll(playlists);
        _apiKey = _extractApiKey(response.body);
        _clientVersion = _extractClientVersion(response.body);
        _continuationToken = _extractContinuationToken(items);
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  /// Fetches more playlists. When a search is active, keeps fetching
  /// subsequent pages automatically (up to a safety cap) until a
  /// newly-fetched page contains at least one match, or there are no more
  /// pages — instead of requiring the user to tap repeatedly for a single
  /// page that may contain zero matches.
  Future<void> _loadMore() async {
    final apiKey = _apiKey;
    final clientVersion = _clientVersion;
    if (apiKey == null || clientVersion == null) return;
    if (_isLoadingMore || _continuationToken == null) return;

    setState(() => _isLoadingMore = true);
    final isFiltering = _searchQuery.isNotEmpty;
    const maxHops = 15;
    var hops = 0;
    try {
      while (_continuationToken != null && hops < maxHops) {
        hops++;
        final response = await _fetchContinuation(
          apiKey: apiKey,
          clientVersion: clientVersion,
          token: _continuationToken!,
        );
        if (response == null) {
          throw Exception('تعذر تحميل المزيد من قوائم التشغيل');
        }
        final items = _continuationItems(response);
        final playlists = _parsePlaylistItems(items);
        final matchedCount = playlists.where(_matchesFilters).length;

        _playlists.addAll(playlists);
        _continuationToken = _extractContinuationToken(items);

        if (!isFiltering || matchedCount > 0) break;
      }
      setState(() => _isLoadingMore = false);
    } catch (error) {
      setState(() => _isLoadingMore = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  void _openPlaylist(_ChannelPlaylist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YoutubePlaylistPage(
          playlistUrl:
              'https://www.youtube.com/playlist?list=${playlist.playlistId}',
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: TextField(
        controller: _searchController,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: 'ابحث في قوائم التشغيل...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _searchController.clear,
                ),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    if (_playlists.isEmpty) {
      return const Center(child: Text('لا توجد قوائم تشغيل.'));
    }

    final filtered = _filteredPlaylists;
    final showLoadMore = _continuationToken != null;
    final hasNoMatches = filtered.isEmpty;

    return Column(
      children: [
        _buildSearchField(),
        Expanded(
          child: hasNoMatches && !showLoadMore
              ? const Center(child: Text('لا توجد نتائج مطابقة.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: (hasNoMatches ? 1 : filtered.length) +
                        (showLoadMore ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (hasNoMatches && index == 0) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                                'لا توجد نتائج مطابقة ضمن قوائم التشغيل المحمّلة.'),
                          ),
                        );
                      }
                      final itemIndex = hasNoMatches ? index - 1 : index;
                      if (itemIndex >= filtered.length) {
                        return Center(
                          child: _isLoadingMore
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(),
                                )
                              : OutlinedButton.icon(
                                  onPressed: _loadMore,
                                  icon: const Icon(Icons.expand_more),
                                  label: const Text('تحميل المزيد'),
                                ),
                        );
                      }
                      final playlist = filtered[itemIndex];
                      return Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openPlaylist(playlist),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                                child: Stack(
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: playlist.thumbnailUrl,
                                      width: 120,
                                      height: 90,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 120,
                                        height: 90,
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2)),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        width: 120,
                                        height: 90,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.broken_image,
                                            color: Colors.grey),
                                      ),
                                    ),
                                    const Positioned.fill(
                                      child: Center(
                                        child: Icon(Icons.playlist_play,
                                            color: Colors.white, size: 32),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        playlist.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      if (playlist.videoCount.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          playlist.videoCount,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(Icons.chevron_left,
                                    color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
