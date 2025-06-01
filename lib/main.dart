import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:radiomr/l10n/localization.dart';
import 'pages/home_page.dart';
import 'pages/info_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audio_service/audio_service.dart';
import 'widgets/audio_player_service.dart';
import 'package:provider/provider.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  print("Initializing firebase");

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  print("Background message handler registered");

  if (Platform.isIOS) {
    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    print('User granted permission: ${settings.authorizationStatus}');

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  print("Notification permissions handled");
  await subscribeToGlobalTopic();
  print("Subscribed to 'all-users' topic");

  final audioHandler = await initAudioService();

  runApp(
    Provider<AudioHandler>.value(
      value: audioHandler,
      child: const RadioApp(),
    ),
  );
}

Future<void> subscribeToGlobalTopic() async {
  try {
    await FirebaseMessaging.instance
        .subscribeToTopic('all-users')
        .timeout(const Duration(seconds: 10));
    print('Successfully subscribed to the "all-users" topic.');
  } catch (e) {
    print('Error subscribing to topic: $e');
  }
}

class RadioApp extends StatefulWidget {
  const RadioApp({super.key});

  @override
  State<RadioApp> createState() => _RadioAppState();

  static _RadioAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_RadioAppState>();
}

class _RadioAppState extends State<RadioApp> {
  Locale _locale = const Locale('fr');

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('user_language') ?? 'fr';
    setState(() {
      _locale = Locale(languageCode);
    });
  }

  Future<void> _changeLanguage(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_language', locale.languageCode);
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Mauritanie',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Colors.green,
        ),
        textTheme: Theme.of(context).textTheme.apply(
              fontFamily: _locale.languageCode == 'ar'
                  ? GoogleFonts.tajawal().fontFamily
                  : GoogleFonts.poppins().fontFamily,
            ),
      ),
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('ar', 'AE'),
        Locale('en', 'US'),
      ],
      home: const SplashScreen(), // Set SplashScreen as the initial page
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 200,
          height: 200,
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final _pages = [
    const HomePage(),
    const InfoPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final radioAppState = RadioApp.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.title ?? 'Radio Mauritanie'),
        actions: [
          PopupMenuButton<Locale>(
            icon: Icon(Icons.language, color: Colors.grey[800]),
            onSelected: (locale) {
              if (radioAppState != null) {
                radioAppState._changeLanguage(locale);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: Locale('fr', 'FR'),
                child: Text('Français'),
              ),
              const PopupMenuItem(
                value: Locale('ar', 'AE'),
                child: Text('العربية'),
              ),
            ],
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: RadioApp.of(context)?._locale.languageCode == 'ar'
            ? GoogleFonts.tajawal(fontWeight: FontWeight.bold)
            : GoogleFonts.poppins(fontWeight: FontWeight.bold),
        unselectedLabelStyle: RadioApp.of(context)?._locale.languageCode == 'ar'
            ? GoogleFonts.tajawal()
            : GoogleFonts.poppins(),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.radio),
            label: AppLocalizations.of(context)?.home ?? 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.newspaper),
            label: AppLocalizations.of(context)?.info ?? 'Infos',
          ),
        ],
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
