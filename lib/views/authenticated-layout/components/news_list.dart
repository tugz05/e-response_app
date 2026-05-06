import 'package:e_response_app_nemsu/services/news_service.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/components/news_card.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/components/newscard_loading.dart';
import 'package:flutter/material.dart';

class NewsListScreen extends StatefulWidget {
  const NewsListScreen({super.key});

  @override
  _NewsListScreenState createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  final NewsService _newsService = NewsService();
  late Future<List<News>> _newsFuture;

  @override
  void initState() {
    super.initState();
    _newsFuture = _newsService.fetchNews();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: FutureBuilder<List<News>>(
        future: _newsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show loading placeholders
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5, // Display 5 placeholders
              itemBuilder: (context, index) => NewsCardLoading(),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No news available'));
          }

          final newsList = snapshot.data!;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: newsList.length,
            itemBuilder: (context, index) {
              final news = newsList[index];
              return NewsCard(
                title: news.title,
                date: news.createdAt,
                imageUrl: news.bgImage ?? 'https://fakeimg.pl/150x150/3409e0/ffffff?text=No+Image&font=noto&font_size=12',
                onTap: () {
                  // Print the ID of the clicked news
                  print('News ID: ${news.id}');
                },
              );
            },
          );
        },
      ),
    );
  }
}
