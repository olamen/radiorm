import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:rfw/rfw.dart';

import '../widgets/rfw_local_widgets.dart';

/// Loading state exposed to the UI while the remote widget library is
/// fetched, cached, or falls back to the bundled copy.
enum RfwLoadState { loading, ready, error }

/// Loads and manages a Remote Flutter Widgets ("server-driven UI") library.
///
/// This lets us change the layout, text, colors, and links of the panel it
/// renders directly from our own server (by replacing the `.rfw` binary
/// file at [remoteUrl]) without shipping a new build to the App Store or
/// Google Play.
///
/// Loading order, most preferred first:
/// 1. Fresh copy fetched over the network (and cached to disk on success).
/// 2. Last-known-good copy cached on disk from a previous successful fetch.
/// 3. Copy bundled with the app as an asset, so there is always something
///    reasonable to show, even offline on first launch.
class RfwService {
  RfwService({required this.remoteUrl, required this.cacheFileName});

  /// URL of the compiled binary widget library (`.rfw`) on the server.
  final String remoteUrl;

  /// File name used to cache the last successfully loaded library on disk.
  final String cacheFileName;

  static const LibraryName coreName = LibraryName(<String>['core', 'widgets']);
  static const LibraryName localName = LibraryName(<String>['local']);
  static const LibraryName remoteName = LibraryName(<String>['remote']);
  static const FullyQualifiedWidgetName rootWidget =
      FullyQualifiedWidgetName(remoteName, 'root');

  final Runtime runtime = Runtime();
  final DynamicContent data = DynamicContent();

  final ValueNotifier<RfwLoadState> state =
      ValueNotifier<RfwLoadState>(RfwLoadState.loading);

  bool _localLibrariesReady = false;

  void _ensureLocalLibraries() {
    if (_localLibrariesReady) return;
    runtime.update(coreName, createCoreWidgets());
    runtime.update(localName, createRfwLocalWidgets());
    _localLibrariesReady = true;
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$cacheFileName');
  }

  /// Fetches the remote library (falling back to cache/bundled asset as
  /// needed) and updates the [runtime] so the UI re-renders.
  Future<void> load() async {
    _ensureLocalLibraries();
    state.value = RfwLoadState.loading;

    Uint8List? bytes = await _fetchFromNetwork();
    bytes ??= await _readCachedBytes();
    bytes ??= await _readBundledBytes();

    if (bytes == null) {
      state.value = RfwLoadState.error;
      return;
    }

    try {
      runtime.update(remoteName, decodeLibraryBlob(bytes));
      state.value = RfwLoadState.ready;
    } catch (e) {
      debugPrint('RfwService: failed to decode widget library: $e');
      state.value = RfwLoadState.error;
    }
  }

  Future<Uint8List?> _fetchFromNetwork() async {
    try {
      final response = await http
          .get(Uri.parse(remoteUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        try {
          final file = await _cacheFile();
          await file.writeAsBytes(bytes, flush: true);
        } catch (e) {
          debugPrint('RfwService: failed to cache remote library: $e');
        }
        return bytes;
      }
      debugPrint('RfwService: unexpected status ${response.statusCode}');
    } catch (e) {
      debugPrint('RfwService: network fetch failed: $e');
    }
    return null;
  }

  Future<Uint8List?> _readCachedBytes() async {
    try {
      final file = await _cacheFile();
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('RfwService: failed to read cached library: $e');
    }
    return null;
  }

  Future<Uint8List?> _readBundledBytes() async {
    try {
      final asset = await rootBundle.load('assets/rfw/home.rfw');
      return asset.buffer.asUint8List();
    } catch (e) {
      debugPrint('RfwService: failed to load bundled fallback library: $e');
    }
    return null;
  }

  void dispose() {
    state.dispose();
  }
}
