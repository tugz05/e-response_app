import 'dart:convert';

import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/content_ui.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Same feed as Tips → Preparedness (`Pages` with emergency-preparedness).
const String _kPreparednessListPath = 'api/v1/emergency-preparedness';

class ListTipsDashboard extends StatefulWidget {
  const ListTipsDashboard({super.key});

  @override
  State<ListTipsDashboard> createState() => _ListTipsDashboardState();
}

class _ListTipsDashboardState extends State<ListTipsDashboard> {
  List<dynamic> _tips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTips();
  }

  Future<void> fetchTips() async {
    final Uri url = Uri.parse(ApiUrl.getServiceUrl(_kPreparednessListPath));
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
          _tips = data['data'] ?? [];
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: 252,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder:
              (_, __) => const SizedBox(
                width: 252,
                child: ContentLoadingList(compact: true, itemCount: 1),
              ),
        ),
      );
    }

    if (_tips.isEmpty) {
      return const ContentEmptyState(
        title: 'No preparedness items yet',
        message:
            'Emergency preparedness articles from CDRRMO will show here when published.',
        icon: Icons.health_and_safety_outlined,
      );
    }

    return SizedBox(
      height: 252,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _tips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int index) {
          final tip = _tips[index];
          final String title = (tip['title'] ?? '').toString();
          final String excerpt = contentPlainText(tip['content']?.toString());
          final String dateLabel = contentDateLabel(
            tip['created_at']?.toString(),
          );

          final tipMap = Map<String, dynamic>.from(tip as Map);
          final String? imageUrl = contentItemImageUrl(tipMap);

          return SizedBox(
            width: 252,
            child: ContentFeedCard(
              title: title.isEmpty ? 'Untitled article' : title,
              excerpt:
                  excerpt.isEmpty
                      ? 'Open to read the full preparedness guidance.'
                      : excerpt,
              dateLabel: dateLabel,
              imageUrl: imageUrl,
              icon: Icons.health_and_safety_outlined,
              accentColor: AppColors.primary,
              compact: true,
              onTap: () {
                final url =
                    '${ApiUrl.getServiceUrl(_kPreparednessListPath)}/${tip['id']}';
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
        },
      ),
    );
  }
}
