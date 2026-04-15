import 'dart:convert';

import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/content_ui.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Pages extends StatefulWidget {
  const Pages({
    super.key,
    required this.apiUrl,
    required this.titleText,
    this.subtitleText,
    this.icon = Icons.article_outlined,
    this.accentColor = AppColors.primary,
    this.showHeader = true,
  });

  final String apiUrl;
  final String titleText;
  final String? subtitleText;
  final IconData icon;
  final Color accentColor;
  final bool showHeader;

  @override
  State<Pages> createState() => _PagesState();
}

class _PagesState extends State<Pages> with WidgetsBindingObserver {
  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchItems();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchItems();
    }
  }

  Future<void> fetchItems() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final url = Uri.parse(ApiUrl.getServiceUrl(widget.apiUrl));
    try {
      final response = await http.get(url);

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _items = data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Unable to load content right now.';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  String _defaultSubtitle() {
    if (widget.subtitleText != null) {
      return widget.subtitleText!;
    }
    if (widget.apiUrl.contains('news')) {
      return 'Official announcements and timely updates for responders.';
    }
    if (widget.apiUrl.contains('emergency-preparedness')) {
      return 'Preparedness references and practical response guidance.';
    }
    return 'Actionable reminders and practical safety recommendations.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: fetchItems,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            if (widget.showHeader) ...[
              Text(
                widget.titleText,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _defaultSubtitle(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (_isLoading)
              const ContentLoadingList(itemCount: 4)
            else if (_errorMessage != null)
              ContentEmptyState(
                title: 'Could not load content',
                message: _errorMessage!,
                icon: widget.icon,
              )
            else if (_items.isEmpty)
              ContentEmptyState(
                title: 'Nothing to show yet',
                message:
                    'Content from this section will appear here once available.',
                icon: widget.icon,
              )
            else
              Column(
                children:
                    _items.asMap().entries.map((entry) {
                      final item = entry.value;
                      final String title = (item['title'] ?? '').toString();
                      final String excerpt = contentPlainText(
                        item['content']?.toString(),
                      );
                      final String dateLabel = contentDateLabel(
                        item['created_at']?.toString(),
                      );
                      final String? imageUrl = item['bg_image']?.toString();

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key == _items.length - 1 ? 0 : 12,
                        ),
                        child: ContentFeedCard(
                          title: title.isNotEmpty ? title : 'Untitled item',
                          excerpt:
                              excerpt.isNotEmpty
                                  ? excerpt
                                  : 'Open this item to read the full details.',
                          dateLabel: dateLabel,
                          imageUrl: imageUrl,
                          icon: widget.icon,
                          accentColor: widget.accentColor,
                          onTap: () {
                            final url =
                                '${ApiUrl.getServiceUrl(widget.apiUrl)}/${item['id']}';
                            final cleanedUrl = url.replaceAll('api/v1/', '');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => WebViewScreen(
                                      url: cleanedUrl,
                                      titleText: title,
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
