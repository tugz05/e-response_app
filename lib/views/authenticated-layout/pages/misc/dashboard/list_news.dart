import 'dart:convert';
import 'dart:math' as math;

import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/content_ui.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ListNewsDashboard extends StatefulWidget {
  const ListNewsDashboard({super.key});

  @override
  State<ListNewsDashboard> createState() => _ListNewsDashboardState();
}

class _ListNewsDashboardState extends State<ListNewsDashboard> {
  List<dynamic> _news = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchNews();
  }

  Future<void> fetchNews() async {
    final Uri url = Uri.parse(ApiUrl.getServiceUrl('api/v1/news'));
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) {
          return;
        }
        setState(() {
          _news = data['data'] ?? [];
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ContentLoadingList(itemCount: 3);
    }

    if (_news.isEmpty) {
      return const ContentEmptyState(
        title: 'No news yet',
        message: 'Fresh advisories and official updates will appear here.',
        icon: Icons.newspaper_outlined,
      );
    }

    final int itemCount = math.min(_news.length, 3);

    return Column(
      children: List.generate(itemCount, (index) {
        final item = _news[index];
        final String title = (item['title'] ?? '').toString();
        final String excerpt = contentPlainText(item['content']?.toString());
        final String dateLabel = contentDateLabel(
          item['created_at']?.toString(),
        );
        final String? imageUrl = item['bg_image']?.toString();

        return Padding(
          padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 12),
          child: ContentFeedCard(
            title: title.isEmpty ? 'Untitled update' : title,
            excerpt:
                excerpt.isEmpty
                    ? 'Open this update to read the full details.'
                    : excerpt,
            dateLabel: dateLabel,
            imageUrl: imageUrl,
            icon: Icons.newspaper_outlined,
            onTap: () {
              final url =
                  '${ApiUrl.getServiceUrl('api/v1/news')}/${item['id']}';
              final cleanedUrl = url.replaceAll('api/v1/', '');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          WebViewScreen(url: cleanedUrl, titleText: title),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
