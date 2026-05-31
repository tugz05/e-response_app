import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/pages.dart';
import 'package:flutter/material.dart';

class TipsPage extends StatelessWidget {
  const TipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        color: AppColors.background,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preparedness & Tips',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Browse preparedness references and practical safety reminders in one place.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      // Sunken tray — slightly blue-tinted so the white pill
                      // has contrast without a harsh border.
                      color: AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      // White pill with a soft shadow — "lifts" above the tray.
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowSoft,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      // Active label: navy bold. Inactive: muted regular.
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textMuted,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5,
                      ),
                      dividerColor: Colors.transparent,
                      // Suppress the default splash so it looks like a clean
                      // segmented control, not a button bar.
                      overlayColor:
                          const WidgetStatePropertyAll(Colors.transparent),
                      splashBorderRadius: BorderRadius.circular(12),
                      tabs: const [
                        Tab(text: 'Preparedness'),
                        Tab(text: 'Safety Tips'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  Pages(
                    key: PageStorageKey('preparedness-feed'),
                    apiUrl: 'api/v1/emergency-preparedness',
                    titleText: 'Emergency Preparedness',
                    icon: Icons.health_and_safety_outlined,
                    accentColor: AppColors.primary,
                    showHeader: false,
                  ),
                  Pages(
                    key: PageStorageKey('tips-feed'),
                    apiUrl: 'api/v1/safety-tips',
                    titleText: 'Safety Tips',
                    icon: Icons.lightbulb_outline_rounded,
                    accentColor: AppColors.secondary,
                    showHeader: false,
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
