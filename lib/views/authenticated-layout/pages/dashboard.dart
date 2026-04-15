import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/dashboard/list_news.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/dashboard/list_tips.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/content_ui.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/show_card.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String userName = 'Responder';
  String greeting = 'Good Morning';

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _updateGreeting();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      userName = prefs.getString('name') ?? 'Responder';
    });
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    setState(() {
      if (hour < 12) {
        greeting = 'Good Morning';
      } else if (hour < 18) {
        greeting = 'Good Afternoon';
      } else {
        greeting = 'Good Evening';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: () async {
          _updateGreeting();
          await _loadUserName();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            Text(
              '$greeting, $userName',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Stay alert and review the most relevant community updates before your next response.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            const ShowCard(),
            const SizedBox(height: 22),
            const ContentSectionHeader(
              title: 'Preparedness Snapshot',
              subtitle:
                  'Quick-read guidance to keep your response decisions sharp.',
            ),
            const SizedBox(height: 12),
            const ListTipsDashboard(),
            const SizedBox(height: 22),
            const ContentSectionHeader(
              title: 'Latest News',
              subtitle:
                  'Recent announcements and advisories relevant to responders.',
            ),
            const SizedBox(height: 12),
            const ListNewsDashboard(),
          ],
        ),
      ),
    );
  }
}
