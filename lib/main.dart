import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:radiomr/firebase_options.dart';
import 'package:radiomr/l10n/localization.dart';
// import 'package:radiomr/pages/info_page.dart';
import 'package:radiomr/pages/musicHome.dart';
import 'package:radiomr/services/firebase_messagin.dart';
import 'package:radiomr/services/local_notification_service.dart';
import 'pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audio_service/audio_service.dart';
import 'widgets/audio_player_service.dart';
import 'package:provider/provider.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Don't initialize Firebase here if it's already initialized in main()
  // The background handler runs in an isolate, so we need to initialize Firebase
  // but we should use a try-catch to handle the duplicate app error
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Ignore duplicate app error
    print('Firebase already initialized in background handler: $e');
  }

  // Handle your background message here
  print('Background message received: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final localnotificationservice = LocalNotificationsService.instance();
  await localnotificationservice.init();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Clear badge when app starts
  if (Platform.isIOS) {
    //FlutterAppBadger.removeBadge();
  }

  // Listen for foreground messages
  final firebaseMessaging = FirebaseMessagingService.instance();
  firebaseMessaging.init(localNotificationsService: localnotificationservice);

  if (Platform.isIOS) {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // Handle notification taps when app is terminated/background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('Notification opened from background/terminated state');
    // Clear badge when notification is tapped
    if (Platform.isIOS) {
      // FlutterAppBadger.removeBadge();
    }
  });

  // Handle notification tap when app was terminated
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print('App opened from terminated state via notification');
    // Clear badge when app opens from notification
    if (Platform.isIOS) {
      //FlutterAppBadger.removeBadge();
    }
  }

  final audioHandler = await initAudioService();

  runApp(
    Provider<AudioHandler>.value(
      value: audioHandler,
      child: const RadioApp(),
    ),
  );
}

class RadioApp extends StatefulWidget {
  const RadioApp({super.key});

  @override
  State<RadioApp> createState() => _RadioAppState();
}

class _RadioAppState extends State<RadioApp> {
  Locale _locale = const Locale('ar');

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('user_language') ?? 'ar';
    setState(() {
      _locale = Locale(languageCode);
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
        Locale('ar', 'AR'),
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

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const MusicHomePage(),
    //const InfoPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Clear badge when main page loads
    if (Platform.isIOS) {
      //FlutterAppBadger.removeBadge();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Clear badge when app comes to foreground
      if (Platform.isIOS) {
        // FlutterAppBadger.removeBadge();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(AppLocalizations.of(context)?.title ?? 'Radio Mauritanie'),
        actions: [],
      ),
      body: _pages[_currentIndex],
      /*bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey[600],
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.radio),
            label: AppLocalizations.of(context)?.home ?? 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.snowing),
            label: 'ذاكرة الإذاعة',
          ),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),*/
    );
  }
}
