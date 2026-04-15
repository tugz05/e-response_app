import 'dart:convert';

import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/content_ui.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
    final Uri url = Uri.parse(ApiUrl.getServiceUrl('api/v1/safety-tips'));
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
        title: 'No tips yet',
        message: 'Preparedness reminders will show up here once available.',
        icon: Icons.lightbulb_outline_rounded,
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

          return SizedBox(
            width: 252,
            child: ContentFeedCard(
              title: title.isEmpty ? 'Untitled tip' : title,
              excerpt:
                  excerpt.isEmpty
                      ? 'Open this tip to read the full guidance.'
                      : excerpt,
              dateLabel: dateLabel,
              icon: Icons.shield_outlined,
              accentColor: AppColors.secondary,
              compact: true,
              onTap: () {
                final url =
                    '${ApiUrl.getServiceUrl('api/v1/safety-tips')}/${tip['id']}';
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
