import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class YoutubeRelatedVideo {
  const YoutubeRelatedVideo({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
  });

  final String videoId;
  final String title;
  final String thumbnailUrl;
}

class YoutubeWebViewPage extends StatefulWidget {
  const YoutubeWebViewPage({
    super.key,
    required this.url,
    this.title = 'YouTube',
    this.videoId,
    this.relatedVideos = const [],
  });

  final String url;
  final String title;
  final String? videoId;
  final List<YoutubeRelatedVideo> relatedVideos;

  @override
  State<YoutubeWebViewPage> createState() => _YoutubeWebViewPageState();
}

class _YoutubeWebViewPageState extends State<YoutubeWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() {
              _isLoading = true;
            });
          },
          onProgress: (progress) {
            setState(() {
              _isLoading = progress < 100;
            });
          },
          onPageFinished: (_) async {
            setState(() {
              _isLoading = false;
            });
            await _hideSuggestedVideos();
            await _updateNavigationControls();
          },
          onNavigationRequest: (request) {
            if (!_isAllowedVideoNavigation(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    _loadUrl(cacheBust: true);
  }

  bool _isAllowedVideoNavigation(String url) {
    final videoId = widget.videoId;
    if (videoId == null) return true;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.contains('youtube.com')) return true;
    if (uri.path == '/watch') {
      return uri.queryParameters['v'] == videoId;
    }
    return !uri.path.startsWith('/shorts/');
  }

  Future<void> _hideSuggestedVideos() async {
    final videoId = widget.videoId;
    if (videoId == null) return;

    await _controller.runJavaScript('''
      (() => {
        const styleId = 'radiomr-hide-youtube-suggestions';
        if (!document.getElementById(styleId)) {
          const style = document.createElement('style');
          style.id = styleId;
          style.textContent = `
            html,
            body,
            ytm-app,
            ytm-watch,
            ytm-watch-page {
              margin: 0 !important;
              padding: 0 !important;
              width: 100% !important;
              height: 100% !important;
              background: #000 !important;
              overflow: hidden !important;
            }
            ytm-mobile-topbar-renderer,
            ytm-watch-metadata,
            ytm-slim-video-metadata-section-renderer,
            ytm-slim-owner-renderer,
            ytm-item-section-renderer,
            #below,
            #related,
            #comments,
            ytd-comments,
            ytd-comments-header-renderer,
            ytd-watch-next-secondary-results-renderer,
            ytd-compact-video-renderer,
            ytd-compact-playlist-renderer,
            ytd-reel-shelf-renderer,
            ytd-engagement-panel-section-list-renderer[target-id*="comment"],
            ytm-comments-entry-point-header-renderer,
            ytm-comments-entry-point-teaser-renderer,
            ytm-comments-entry-point-renderer,
            ytm-comments-section-renderer,
            ytm-comments-header-renderer,
            ytm-comment-section-renderer,
            ytm-comment-thread-renderer,
            ytm-watch-next-secondary-results-renderer,
            ytm-watch-next-tabbed-results-renderer,
            ytm-video-with-context-renderer,
            ytm-playlist-with-context-renderer,
            ytm-compact-video-renderer,
            ytm-compact-playlist-renderer,
            ytm-reel-shelf-renderer,
            ytm-rich-grid-renderer,
            ytm-engagement-panel-section-list-renderer[target-id*="comment"],
            .ytp-ce-element,
            .ytp-endscreen-content,
            .ytp-pause-overlay,
            .ytp-suggestion-set,
            .ytp-chrome-top,
            .ytp-gradient-top,
            .ytp-title,
            .ytp-chrome-top-buttons,
            [id*="comment" i],
            [class*="comment" i],
            [target-id*="comment" i],
            [section-identifier*="comment" i],
            [data-radiomr-comment],
            [data-radiomr-suggestion] {
              display: none !important;
            }
            #player-container-id,
            #player-container,
            ytm-watch #player,
            ytm-player,
            .player-container {
              position: fixed !important;
              inset: 0 !important;
              width: 100vw !important;
              height: 100vh !important;
              max-height: none !important;
              margin: 0 !important;
              padding: 0 !important;
              background: #000 !important;
              z-index: 9999 !important;
            }
            #movie_player,
            .html5-video-player,
            .html5-video-container,
            .video-stream.html5-main-video,
            video {
              width: 100% !important;
              height: 100% !important;
              max-width: none !important;
              max-height: none !important;
              aspect-ratio: auto !important;
            }
            .html5-video-container,
            .video-stream.html5-main-video,
            video {
              position: absolute !important;
              inset: 0 !important;
              top: 0 !important;
              left: 0 !important;
              transform: none !important;
              object-fit: cover !important;
              object-position: center !important;
            }
            .ytp-cued-thumbnail-overlay,
            .ytp-cued-thumbnail-overlay-image {
              position: absolute !important;
              inset: 0 !important;
              width: 100% !important;
              height: 100% !important;
              aspect-ratio: auto !important;
            }
            .ytp-cued-thumbnail-overlay-image {
              background-size: cover !important;
              background-position: center !important;
            }
          `;
          (document.head || document.documentElement).appendChild(style);
        }

        const hideLinkedSuggestions = () => {
          const forcePlayerToFill = () => {
            document.querySelectorAll([
              '#player-container-id',
              '#player-container',
              'ytm-watch #player',
              'ytm-player',
              '.player-container',
              '#movie_player',
              '.html5-video-player',
              '.html5-video-container',
              '.ytp-cued-thumbnail-overlay',
              '.ytp-cued-thumbnail-overlay-image',
              '.video-stream.html5-main-video',
              'video'
            ].join(',')).forEach((element) => {
              element.style.setProperty('width', '100%', 'important');
              element.style.setProperty('height', '100%', 'important');
              element.style.setProperty('max-width', 'none', 'important');
              element.style.setProperty('max-height', 'none', 'important');
            });

            document.querySelectorAll([
              '.html5-video-container',
              '.video-stream.html5-main-video',
              'video',
              '.ytp-cued-thumbnail-overlay',
              '.ytp-cued-thumbnail-overlay-image'
            ].join(',')).forEach((element) => {
              element.style.setProperty('position', 'absolute', 'important');
              element.style.setProperty('inset', '0', 'important');
              element.style.setProperty('top', '0', 'important');
              element.style.setProperty('left', '0', 'important');
              element.style.setProperty('transform', 'none', 'important');
            });

            document.querySelectorAll('video').forEach((video) => {
              video.style.setProperty('object-fit', 'cover', 'important');
              video.style.setProperty('object-position', 'center', 'important');
            });

            const fillAncestors = (start) => {
              let el = start && start.parentElement;
              while (el && el !== document.body && el !== document.documentElement) {
                el.style.setProperty('width', '100%', 'important');
                el.style.setProperty('height', '100%', 'important');
                el.style.setProperty('max-width', 'none', 'important');
                el.style.setProperty('max-height', 'none', 'important');
                el.style.setProperty('margin', '0', 'important');
                el.style.setProperty('padding', '0', 'important');
                el.style.setProperty('top', '0', 'important');
                el.style.setProperty('left', '0', 'important');
                el.style.setProperty('aspect-ratio', 'auto', 'important');
                el = el.parentElement;
              }
            };
            document.querySelectorAll(
              'video, .ytp-cued-thumbnail-overlay-image, .ytp-cued-thumbnail-overlay',
            ).forEach(fillAncestors);

            document.querySelectorAll([
              '.ytp-chrome-top',
              '.ytp-gradient-top',
              '.ytp-title',
              '.ytp-chrome-top-buttons',
            ].join(',')).forEach((element) => {
              element.style.setProperty('display', 'none', 'important');
            });

            window.dispatchEvent(new Event('resize'));
            document.querySelectorAll('#movie_player, ytm-player').forEach((el) => {
              el.dispatchEvent(new Event('resize'));
            });
          };

          forcePlayerToFill();
          if (!window.radiomrPlayerFillInit) {
            window.radiomrPlayerFillInit = true;
            window.addEventListener('orientationchange', forcePlayerToFill);
            setTimeout(forcePlayerToFill, 300);
            setTimeout(forcePlayerToFill, 1000);
            setInterval(forcePlayerToFill, 500);
          }
          document.querySelectorAll('a[href]').forEach((link) => {
            let target;
            try {
              target = new URL(link.href, location.href);
            } catch (_) {
              return;
            }

            const linkedVideo = target.searchParams.get('v');
            const linksAnotherVideo = target.pathname === '/watch' &&
                linkedVideo && linkedVideo !== '$videoId';
            const linksPlaylist = target.pathname === '/playlist' ||
                (target.pathname === '/watch' && target.searchParams.has('list'));
            if (!linksAnotherVideo && !linksPlaylist &&
                !target.pathname.startsWith('/shorts/')) {
              return;
            }

            const card = link.closest([
              'ytm-video-with-context-renderer',
              'ytm-playlist-with-context-renderer',
              'ytm-compact-video-renderer',
              'ytm-compact-playlist-renderer',
              'ytm-reel-item-renderer',
              'ytd-compact-video-renderer',
              'ytd-compact-playlist-renderer',
              'ytd-reel-item-renderer'
            ].join(','));
            (card || link).setAttribute('data-radiomr-suggestion', '');
          });

          document.querySelectorAll('*').forEach((element) => {
            const identity = [
              element.localName,
              element.id,
              element.className,
              element.getAttribute?.('target-id'),
              element.getAttribute?.('section-identifier'),
            ].filter((value) => typeof value === 'string').join(' ');
            if (!identity.toLowerCase().includes('comment')) return;

            const section = element.closest([
              'ytm-item-section-renderer',
              'ytm-engagement-panel-section-list-renderer',
              'ytd-item-section-renderer',
              'ytd-engagement-panel-section-list-renderer'
            ].join(','));
            (section || element).setAttribute('data-radiomr-comment', '');
          });

          document.querySelectorAll(
            'h1, h2, h3, button, span, yt-formatted-string',
          ).forEach((element) => {
            const text = element.textContent?.trim() || '';
            if (!/^(comments?|التعليقات)(\s|\$)/i.test(text)) return;

            const section = element.closest([
              'ytm-item-section-renderer',
              'ytm-engagement-panel-section-list-renderer',
              'ytd-item-section-renderer',
              'ytd-engagement-panel-section-list-renderer'
            ].join(','));
            (section || element).setAttribute('data-radiomr-comment', '');
          });
        };

        hideLinkedSuggestions();
        window.radiomrSuggestionObserver?.disconnect();
        window.radiomrSuggestionObserver = new MutationObserver(
          hideLinkedSuggestions,
        );
        window.radiomrSuggestionObserver.observe(document.documentElement, {
          childList: true,
          subtree: true,
        });
      })();
    ''');
  }

  Future<void> _loadUrl({bool cacheBust = false}) async {
    await _controller.clearCache();

    final uri = Uri.parse(widget.url);
    final targetUri = cacheBust
        ? uri.replace(
            queryParameters: {
              ...uri.queryParameters,
              'cb': DateTime.now().millisecondsSinceEpoch.toString(),
            },
          )
        : uri;

    await _controller.loadRequest(
      targetUri,
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    );
  }

  Future<void> _updateNavigationControls() async {
    final canGoBack = await _controller.canGoBack();
    final canGoForward = await _controller.canGoForward();
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open browser.')),
      );
    }
  }

  Future<void> _handlePlayerMenu(String action) async {
    switch (action) {
      case 'back':
        await _controller.goBack();
        await _updateNavigationControls();
      case 'forward':
        await _controller.goForward();
        await _updateNavigationControls();
      case 'refresh':
        await _loadUrl(cacheBust: true);
      case 'external':
        await _openInBrowser();
    }
  }

  void _openRelatedVideo(YoutubeRelatedVideo video) {
    final remainingVideos = widget.relatedVideos
        .where((item) => item.videoId != video.videoId)
        .toList();
    final url = Uri.https(
      'www.youtube.com',
      '/watch',
      {'v': video.videoId},
    ).toString();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => YoutubeWebViewPage(
          url: url,
          title: video.title,
          videoId: video.videoId,
          relatedVideos: remainingVideos,
        ),
      ),
    );
  }

  Widget _buildStationSection() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إذاعة موريتانيا',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'الصوت الرسمي للجمهورية الإسلامية الموريتانية',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.relatedVideos.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'فيديوهات أخرى من إذاعة موريتانيا',
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  mainAxisExtent: 205,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: widget.relatedVideos.length,
                itemBuilder: (context, index) {
                  final video = widget.relatedVideos[index];
                  final thumbnailUrl = video.thumbnailUrl.isNotEmpty
                      ? video.thumbnailUrl
                      : 'https://i.ytimg.com/vi/${video.videoId}/hqdefault.jpg';
                  return InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _openRelatedVideo(video),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: thumbnailUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(Icons.play_circle_outline),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          video.title,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        titleSpacing: 8,
        title: Text(
          widget.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontSize: 14, height: 1.3),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Video options',
            onSelected: _handlePlayerMenu,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'back',
                enabled: _canGoBack,
                child: const ListTile(
                  leading: Icon(Icons.arrow_back_ios_new),
                  title: Text('Back'),
                ),
              ),
              PopupMenuItem(
                value: 'forward',
                enabled: _canGoForward,
                child: const ListTile(
                  leading: Icon(Icons.arrow_forward_ios),
                  title: Text('Forward'),
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh'),
                ),
              ),
              const PopupMenuItem(
                value: 'external',
                child: ListTile(
                  leading: Icon(Icons.open_in_new),
                  title: Text('Open in YouTube'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          if (widget.videoId == null)
            Expanded(
              child: WebViewWidget(controller: _controller),
            )
          else
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: WebViewWidget(controller: _controller),
                  ),
                  Expanded(
                    child: _buildStationSection(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
