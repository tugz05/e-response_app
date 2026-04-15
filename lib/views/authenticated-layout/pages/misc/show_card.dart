import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/content_ui.dart';
import 'package:flutter/material.dart';

class ShowCard extends StatelessWidget {
  const ShowCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContentHeroCard(
      badge: 'Responder Workspace',
      icon: Icons.emergency_share_outlined,
      title: 'Stay ready to report, monitor, and respond.',
      subtitle:
          'Use this workspace to review current advisories, scan safety guidance, and stay prepared before an incident happens.',
      highlights: ['Real-time updates', 'Safety guidance', 'Account tools'],
    );
  }
}
