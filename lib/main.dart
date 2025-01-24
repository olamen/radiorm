import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stream2/radio1.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(RadioApp());
}

class RadioApp extends StatefulWidget {
  @override
  _RadioAppState createState() => _RadioAppState();
}

class _RadioAppState extends State<RadioApp> {
  Locale _locale = const Locale('ar');

  void _changeLanguage(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''),
        Locale('fr', ''),
        Locale('en', ''),
      ],
      theme: ThemeData(
        fontFamily: _locale.languageCode == 'ar' ? 'Cairo' : null,
      ),
      home: RadioPlayerScreen(onLanguageChanged: _changeLanguage),
    );
  }
}
