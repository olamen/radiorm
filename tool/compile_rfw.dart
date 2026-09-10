// Compiles every `*.rfwtxt` file under `assets/rfw/` into the binary
// `*.rfw` format that the app fetches from the server and bundles as an
// offline fallback asset.
//
// Usage:
//   dart run tool/compile_rfw.dart
//
// After running, upload the generated `assets/rfw/home.rfw` file to your
// server (e.g. https://radiomauritanie.mr/rfw/home.rfw — see
// `rfwUpdatesUrl` in lib/const.dart). You only need to rebuild/resubmit the
// Flutter app itself when you change Dart code; content/layout changes in
// the `.rfwtxt` source just need to be recompiled and re-uploaded.

import 'dart:io';

import 'package:rfw/formats.dart' show parseLibraryFile, encodeLibraryBlob;

Future<void> main(List<String> args) async {
  final dir = Directory('assets/rfw');
  if (!dir.existsSync()) {
    stderr.writeln('No assets/rfw directory found.');
    exitCode = 1;
    return;
  }

  final sources = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.rfwtxt'))
      .toList();

  if (sources.isEmpty) {
    stdout.writeln('No .rfwtxt files found in assets/rfw.');
    return;
  }

  var hadError = false;
  for (final file in sources) {
    final source = await file.readAsString();
    try {
      final library = parseLibraryFile(source);
      final bytes = encodeLibraryBlob(library);
      final outPath = file.path.replaceAll(RegExp(r'\.rfwtxt$'), '.rfw');
      await File(outPath).writeAsBytes(bytes, flush: true);
      stdout.writeln(
        'Compiled ${file.path} -> $outPath (${bytes.length} bytes)',
      );
    } catch (e) {
      stderr.writeln('Failed to compile ${file.path}: $e');
      hadError = true;
    }
  }

  if (hadError) {
    exitCode = 1;
  }
}
