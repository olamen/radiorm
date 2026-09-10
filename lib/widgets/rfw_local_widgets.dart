import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rfw/rfw.dart';

/// Local widgets exposed to the remote ("server-driven") widget library.
///
/// These wrap native Flutter functionality that the RFW core widget set
/// does not provide (like cached network images), so the server-hosted
/// `.rfwtxt`/`.rfw` file can reference them by name, e.g.:
///
/// ```
/// import local;
/// widget root = RemoteImage(url: "https://example.com/banner.png", height: 160.0);
/// ```
LocalWidgetLibrary createRfwLocalWidgets() {
  return LocalWidgetLibrary(<String, LocalWidgetBuilder>{
    'RemoteImage': (BuildContext context, DataSource source) {
      final String? url = source.v<String>(<Object>['url']);
      if (url == null || url.isEmpty) {
        return const SizedBox.shrink();
      }
      final double? width = source.v<double>(<Object>['width']);
      final double? height = source.v<double>(<Object>['height']);
      return CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => SizedBox(
          width: width,
          height: height,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => const SizedBox.shrink(),
      );
    },
  });
}
