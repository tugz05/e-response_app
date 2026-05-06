import 'package:e_response_app_nemsu/helpers/app_mobile_role.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/content_ui.dart';
import 'package:flutter/material.dart';

class ShowCard extends StatelessWidget {
  const ShowCard({
    super.key,
    this.locationSection,
    this.appRole = AppMobileRole.citizen,
  });

  final Widget? locationSection;
  final AppMobileRole appRole;

  @override
  Widget build(BuildContext context) {
    final badge = switch (appRole) {
      AppMobileRole.staff => 'Staff / Rescuer',
      AppMobileRole.admin => 'Administrator',
      AppMobileRole.citizen => 'Responder',
    };
    return ContentHeroCard(
      badge: badge,
      icon: Icons.emergency_share_outlined,
      title: 'Ready to report when you need help.',
      subtitle: 'News and tips below; full report history is on Profile.',
      highlights: const [],
      locationSection: locationSection,
    );
  }
}
