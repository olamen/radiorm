import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../generated/intl/messages_all.dart';

class AppLocalizations {
  AppLocalizations();

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static Future<AppLocalizations> load(Locale locale) {
    final String name = locale.countryCode?.isEmpty ?? true
        ? locale.languageCode
        : locale.toString();
    final String localeName = Intl.canonicalizedLocale(name);

    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      return AppLocalizations();
    });
  }

  // Define your keys and localized values using Intl.message
  String get title {
    return Intl.message(
      'Radio Mauritanie',
      name: 'title',
      desc: 'App title',
      locale: Intl.defaultLocale,
    );
  }

  String get home {
    return Intl.message(
      'Home',
      name: 'home',
      desc: 'Home tab',
      locale: Intl.defaultLocale,
    );
  }

  String get info {
    return Intl.message(
      'Infos',
      name: 'info',
      desc: 'Info tab',
      locale: Intl.defaultLocale,
    );
  }

  String get fetchingData {
    return Intl.message(
      'Fetching data...',
      name: 'fetchingData',
      desc: 'Fetching data message',
      locale: Intl.defaultLocale,
    );
  }

  String get infos {
    return Intl.message(
      'Infos',
      name: 'infos',
      desc: 'Infos title',
      locale: Intl.defaultLocale,
    );
  }

  String get loadingNews {
    return Intl.message(
      'Loading News...',
      name: 'loadingNews',
      desc: 'Loading News',
      locale: Intl.defaultLocale,
    );
  }

  String get errorLoadingNews {
    return Intl.message(
      'Error loading news',
      name: 'errorLoadingNews',
      desc: 'Error loading',
      locale: Intl.defaultLocale,
    );
  }

  String get newsTitle {
    return Intl.message(
      'News',
      name: 'newsTitle',
      desc: 'News Title',
      locale: Intl.defaultLocale,
    );
  }

  String get retryButton {
    return Intl.message(
      'Retry',
      name: 'retryButton',
      desc: 'Retry',
      locale: Intl.defaultLocale,
    );
  }

  String get noNewsAvailable {
    return Intl.message(
      'No news available',
      name: 'noNewsAvailable',
      desc: 'No News',
      locale: Intl.defaultLocale,
    );
  }

  String get playButton {
    return Intl.message(
      'Play',
      name: 'playButton',
      desc: 'Play button label',
      locale: Intl.defaultLocale,
    );
  }

  String get stopButton {
    return Intl.message(
      'Stop',
      name: 'stopButton',
      desc: 'Stop button label',
      locale: Intl.defaultLocale,
    );
  }

  String get liveStream {
    return Intl.message(
      'Live Stream',
      name: 'liveStream',
      desc: 'Live stream label',
      locale: Intl.defaultLocale,
    );
  }

  String get playbackError {
    return Intl.message(
      'Playback error. Please try again.',
      name: 'playbackError',
      desc: 'Playback error message',
      locale: Intl.defaultLocale,
    );
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['fr', 'ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) => AppLocalizations.load(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}