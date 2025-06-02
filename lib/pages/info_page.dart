import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../l10n/localization.dart';
import 'detail_news_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  _InfoPageState createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  List<Map<String, dynamic>> newsList = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchNews();
  }

  Future<void> fetchNews() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    final baseUrl = "https://monecole-4jfb.onrender.com";
    final newsApiUrl = "$baseUrl/api/news/";

    try {
      final uri = Uri.parse(newsApiUrl);
      print('Fetching data from: $newsApiUrl');

      final response = await http.get(uri);

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newsItems = data['results'];

        setState(() {
          newsList = newsItems.map((item) {
            final locale = Localizations.localeOf(context).languageCode;
            final isArabic = locale == 'ar';

            return {
              'date': item['news_date']?.toString() ?? 'No Date Available',
              'image': item['news_image'] != null
                  ? "$baseUrl${item['news_image']}"
                  : null,
              'title': isArabic
                  ? item['news_title_ar']?.toString() ?? 'لا عنوان'
                  : item['news_title_fr']?.toString() ?? 'Pas de titre',
              'content': isArabic
                  ? item['news_script_ar']?.toString() ?? 'لا محتوى'
                  : item['news_script_fr']?.toString() ?? 'Pas de contenu',
            };
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Failed to load news: Server returned status ${response.statusCode}';
          isLoading = false;
        });
        print('Failed to load news: ${response.statusCode}');
        print('Response body on error: ${response.body}');
      }
    } catch (error, stackTrace) {
      setState(() {
        errorMessage = 'Error fetching news: $error';
        isLoading = false;
      });
      print('Exception: $error');
      print('StackTrace: $stackTrace');
    }
  }

  String _formatDate(String dateString) {
    try {
      final DateTime dateTime = DateTime.parse(dateString);

      return DateFormat.yMMMEd(Localizations.localeOf(context).toString())
          .format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: buildBody(localizations),
    );
  }

  Widget buildBody(AppLocalizations? localizations) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!),
            ),
            const SizedBox(height: 20),
            Text(
              localizations?.loadingNews ?? 'Loading News...',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      );
    } else if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                localizations?.errorLoadingNews ?? 'Error Loading News:',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  await fetchNews();
                },
                icon: Icon(Icons.refresh),
                label: Text(localizations?.retryButton ?? 'Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (newsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.black54,
              size: 60,
            ),
            const SizedBox(height: 20),
            Text(
              localizations?.noNewsAvailable ?? 'No News Available',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          ],
        ),
      );
    } else {
      return ListView.builder(
        itemCount: newsList.length,
        itemBuilder: (context, index) {
          final item = newsList[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              shadowColor: const Color.fromARGB(255, 249, 249, 249),
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailNewsPage(news: item),
                    ),
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    item['image'] != null
                        ? CachedNetworkImage(
                            imageUrl: item['image']!,
                            width: 120,
                            height: 100,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.green[700]!))),
                            errorWidget: (context, url, error) => Container(
                              width: 120,
                              height: 100,
                              color: Colors.white,
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey),
                            ),
                          )
                        : Container(
                            width: 120,
                            height: 100,
                            color: Colors.white,
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.grey),
                          ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title']!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDate(item['date']!),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
  }
}
