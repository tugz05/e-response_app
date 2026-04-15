import 'dart:convert';
import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:http/http.dart' as http;

class NewsService {
  final String _baseUrl = ApiUrl.getServiceUrl("api/v1/news");

  Future<List<News>> fetchNews() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List newsList = jsonData['data'];
        return newsList.map((news) => News.fromJson(news)).toList();
      } else {
        throw Exception('Failed to load news');
      }
    } catch (e) {
      throw Exception('Error fetching news: $e');
    }
  }
}

class News {
  final int id;
  final String? bgImage;
  final String title;
  final String content;
  final String createdAt;

  News({
    required this.id,
    this.bgImage,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      id: json['id'],
      bgImage: json['bg_image'],
      title: json['title'],
      content: json['content'],
      createdAt: json['created_at'],
    );
  }
}
