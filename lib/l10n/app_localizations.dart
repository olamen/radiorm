import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stream2/l10n/messages_all_locales.dart';

class AppLocalizations {
  static Future<AppLocalizations> load(Locale locale) {
    final String name = locale.languageCode;
    final String localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      return AppLocalizations();
    });
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String get appBarTitle {
    return Intl.message(
      'Radio Mauritanie',
      name: 'appBarTitle',
      desc: 'Title for the AppBar',
    );
  }

  String get appBarTitleAr {
    return Intl.message(
      'إذاعة موريتانيا',
      name: 'appBarTitleAr',
      desc: 'Title for the AppBar in Arabic',
    );
  }

  String get pause {
    return Intl.message(
      'Pause',
      name: 'pause',
      desc: 'Pause button text',
    );
  }

  String get playRadioStream {
    return Intl.message(
      'Play Radio Stream',
      name: 'playRadioStream',
      desc: 'Play button text',
    );
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['fr', 'ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) => AppLocalizations.load(locale);

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
