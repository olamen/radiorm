// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a fr locale. All the
// messages from the main program should be duplicated here with the same
// function name.
// @dart=2.12
// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = MessageLookup();

typedef String? MessageIfAbsent(
    String? messageStr, List<Object>? args);

class MessageLookup extends MessageLookupByLibrary {
  @override
  String get localeName => 'fr';

  @override
  final Map<String, dynamic> messages = _notInlinedMessages(_notInlinedMessages);

  static Map<String, dynamic> _notInlinedMessages(_) => {
      'errorLoadingNews': MessageLookupByLibrary.simpleMessage('Erreur lors du chargement'),
    'fetchingData': MessageLookupByLibrary.simpleMessage('Récupération des données...'),
    'home': MessageLookupByLibrary.simpleMessage('Diffusion'),
    'info': MessageLookupByLibrary.simpleMessage('Actualités'),
    'infos': MessageLookupByLibrary.simpleMessage('Actualités'),
    'liveStream': MessageLookupByLibrary.simpleMessage('Diffusion en direct'),
    'loadingNews': MessageLookupByLibrary.simpleMessage('Chargement des actualités...'),
    'newsTitle': MessageLookupByLibrary.simpleMessage('Actualités'),
    'noNewsAvailable': MessageLookupByLibrary.simpleMessage('Aucune actualité disponible'),
    'playButton': MessageLookupByLibrary.simpleMessage('Écouter'),
    'playbackError': MessageLookupByLibrary.simpleMessage('Erreur de lecture du flux. Veuillez réessayer.'),
    'retryButton': MessageLookupByLibrary.simpleMessage('Réessayer'),
    'stopButton': MessageLookupByLibrary.simpleMessage('Arrêter'),
    'title': MessageLookupByLibrary.simpleMessage('Radio Mauritanie')
  };
}
