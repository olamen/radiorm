import 'package:flutter/material.dart';
import 'package:rfw/rfw.dart';
import 'package:url_launcher/url_launcher.dart';

import '../const.dart';
import '../services/rfw_service.dart';
import 'youtube_webview_page.dart';

/// Displays a "server-driven" panel whose content, layout, and links come
/// from a Remote Flutter Widgets library hosted on our own server
/// (see [rfwUpdatesUrl] in `const.dart`).
///
/// Editing and re-uploading the `.rfw` file on the server changes what is
/// shown here the next time the app fetches it — no App Store / Google Play
/// release is required for content or layout changes made this way.
///
/// Note: per RFW's design, this is meant for content-style panels
/// (announcements, quick links, message-of-the-day), not for the app's
/// core navigation or look-and-feel, which should still be changed in Dart.
class ServerDrivenPage extends StatefulWidget {
  const ServerDrivenPage({super.key});

  @override
  State<ServerDrivenPage> createState() => _ServerDrivenPageState();
}

class _ServerDrivenPageState extends State<ServerDrivenPage> {
  late final RfwService _rfwService;

  @override
  void initState() {
    super.initState();
    _rfwService = RfwService(
      remoteUrl: rfwUpdatesUrl,
      cacheFileName: 'rfw_home_cache.rfw',
    );
    _rfwService.load();
  }

  @override
  void dispose() {
    _rfwService.dispose();
    super.dispose();
  }

  void _handleEvent(String name, DynamicMap args) {
    switch (name) {
      case 'openUrl':
        final url = args['url'] as String?;
        if (url != null && url.isNotEmpty) {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
        break;
      case 'openWebview':
        final url = args['url'] as String?;
        if (url != null && url.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => YoutubeWebViewPage(url: url)),
          );
        }
        break;
      default:
        debugPrint('ServerDrivenPage: unhandled event "$name" ($args)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحديثات والإعلانات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => _rfwService.load(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _rfwService.load,
          child: ValueListenableBuilder<RfwLoadState>(
            valueListenable: _rfwService.state,
            builder: (context, state, _) {
              if (state == RfwLoadState.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state == RfwLoadState.error) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Center(child: Text('تعذر تحميل هذا القسم حالياً.')),
                  ],
                );
              }
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: RemoteWidget(
                  runtime: _rfwService.runtime,
                  data: _rfwService.data,
                  widget: RfwService.rootWidget,
                  onEvent: _handleEvent,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
