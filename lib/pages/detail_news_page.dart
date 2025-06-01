import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart'; 

class DetailNewsPage extends StatelessWidget {
  final Map<String, dynamic> news;

  const DetailNewsPage({super.key, required this.news});

  
  String _formatDate(BuildContext context, String dateString) {
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
    final formattedDate = _formatDate(
        context, news['date'] ?? 'No Date Available'); 

    return Scaffold(
      backgroundColor: Colors.white, 
      appBar: AppBar(
        title: Text(
          news['title'] ??
              'News Details', 
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 18, 
          ),
          overflow: TextOverflow.ellipsis, 
        ),
        backgroundColor: Colors.white, 
        elevation: 4, 
        iconTheme: IconThemeData(color: Colors.grey[800]), 
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start, 
          children: [
            
            if (news['image'] != null) 
              CachedNetworkImage(
                imageUrl: news['image']!,
                width: double.infinity,
                height: 250, 
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 250,
                  color: Colors.grey[300],
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.green[700]!),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 250,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image,
                      size: 50, color: Colors.grey),
                ),
              ),
            
            if (news['image'] != null)
              const Divider(height: 0, color: Colors.grey),

            Padding(
              padding: const EdgeInsets.all(20), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  Text(
                    news['title'] ??
                        'No Title Available', 
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                      height: 1.2, 
                    ),
                  ),
                  const SizedBox(height: 12), 

                  
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 15, 
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 25), 

                  
                  Text(
                    news['content'] ??
                        'No content available for this news item.', 
                    style: const TextStyle(
                      fontSize: 17, 
                      height:
                          1.7, 
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
