import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stream2/l10n/app_localizations.dart';
import 'package:stream2/streamindicator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Locale _locale = const Locale('fr');

  void _changeLanguage(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isArabic = _locale.languageCode == 'ar';

    return MaterialApp(
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
        fontFamily: isArabic ? 'Cairo' : null,
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 1, 90, 20),
          title: Text(
            style: const TextStyle(fontSize: 24, color: Colors.white),
            isArabic
                ? AppLocalizations.of(context).appBarTitleAr
                : AppLocalizations.of(context).appBarTitle,
          ),
          actions: [
            StreamIndicator(),
            PopupMenuButton<Locale>(
              icon: const Icon(Icons.language, color: Colors.white),
              onSelected: _changeLanguage,
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: Locale('ar'), child: Text('العربية')),
                const PopupMenuItem(
                    value: Locale('fr'), child: Text('Français')),
              ],
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration:
                    const BoxDecoration(color: Color.fromARGB(255, 1, 90, 20)),
                child: Text(
                  isArabic ? 'القائمة' : 'Menu',
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.contact_page),
                title: Text(isArabic ? 'اتصل بنا' : 'Contact'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ContactScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        body: Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Image.asset('assets/images/logo.png', height: 100),
                ),
                const SizedBox(height: 20),
                Text(
                  isArabic ? 'أوبريغون' : 'Obregón',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _changeLanguage(const Locale('fr')),
                  child: const Text('Switch to French'),
                ),
                ElevatedButton(
                  onPressed: () => _changeLanguage(const Locale('ar')),
                  child: const Text('Switch to Arabic'),
                ),
                const SizedBox(height: 20),
                
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 1, 90, 20),
        title: Text(
          isArabic ? 'اتصل بنا' : 'Contact',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            isArabic
                ? 'مرحبا بكم في صفحة الاتصال. إذا كنت بحاجة إلى مزيد من المعلومات، يرجى الاتصال بنا.'
                : 'Welcome to the Contact page. If you need more information, please reach out to us.',
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
