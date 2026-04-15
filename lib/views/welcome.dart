import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/components/VButton.dart';
import 'package:e_response_app_nemsu/views/components/VlLogo.dart';
import 'package:e_response_app_nemsu/views/components/misc/footer.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;

    if (!mounted) {
      return;
    }

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacementNamed(context, RouteManager.mainPage);
    } else if (hasSeenWelcome) {
      Navigator.pushReplacementNamed(context, RouteManager.loginPage);
    }
  }

  Future<void> _setFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.background, AppColors.backgroundAlt],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth >= 920;
              final bool compactHeight = constraints.maxHeight < 760;
              final double horizontalPadding = isDesktop ? 32 : 18;

              return Stack(
                children: [
                  const Positioned(
                    top: -70,
                    right: -30,
                    child: _AmbientBubble(size: 190, color: Color(0x2219336A)),
                  ),
                  const Positioned(
                    bottom: -55,
                    left: -25,
                    child: _AmbientBubble(size: 150, color: Color(0x160F766E)),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      compactHeight ? 14 : 18,
                      horizontalPadding,
                      12,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1160),
                      child:
                          isDesktop
                              ? _WelcomeDesktopShell(
                                compactHeight: compactHeight,
                                onStart: _handleStart,
                              )
                              : _WelcomeMobileShell(
                                compactHeight: compactHeight,
                                onStart: _handleStart,
                              ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleStart() async {
    await _setFirstTime();
    if (mounted) {
      Navigator.pushReplacementNamed(context, RouteManager.loginPage);
    }
  }
}

class _WelcomeMobileShell extends StatelessWidget {
  const _WelcomeMobileShell({
    required this.compactHeight,
    required this.onStart,
  });

  final bool compactHeight;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    if (compactHeight) {
      return Column(
        children: [
          Expanded(
            child: _WelcomePrimaryCard(
              compact: true,
              onStart: onStart,
            ),
          ),
          const SizedBox(height: 10),
          const Footer(),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              _WelcomePrimaryCard(
                compact: compactHeight,
                onStart: onStart,
              ),
              SizedBox(height: compactHeight ? 12 : 14),
              Expanded(child: _WelcomeVisualCard(compact: compactHeight)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Footer(),
      ],
    );
  }
}

class _WelcomeDesktopShell extends StatelessWidget {
  const _WelcomeDesktopShell({
    required this.compactHeight,
    required this.onStart,
  });

  final bool compactHeight;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _WelcomePrimaryCard(
                  compact: compactHeight,
                  onStart: onStart,
                ),
              ),
              const SizedBox(width: 22),
              Expanded(child: _WelcomeVisualCard(compact: compactHeight)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Footer(),
      ],
    );
  }
}

class _WelcomePrimaryCard extends StatelessWidget {
  const _WelcomePrimaryCard({
    required this.compact,
    required this.onStart,
  });

  final bool compact;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 20 : 24,
          compact ? 20 : 24,
          compact ? 20 : 24,
          compact ? 18 : 22,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const VLogo(size: 74, topSpacing: 0),
            SizedBox(height: compact ? 12 : 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trusted emergency response',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 14 : 18),
            Text(
              'Report emergencies faster and stay updated.',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Send incident details, attach evidence, and receive official updates from the same mobile app used for response coordination.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textMuted,
                height: 1.45,
              ),
            ),
            SizedBox(height: compact ? 14 : 18),
            Column(
              children: [
                const _FeatureRow(
                  icon: Icons.location_on_outlined,
                  title: 'Location-aware reports',
                  subtitle: 'Share exact incident locations quickly.',
                ),
                const SizedBox(height: 10),
                const _FeatureRow(
                  icon: Icons.campaign_outlined,
                  title: 'Official advisories',
                  subtitle: 'Get trusted news and response updates.',
                ),
                if (!compact) ...[
                  const SizedBox(height: 10),
                  const _FeatureRow(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Preparedness guidance',
                    subtitle: 'Access clear safety and response tips.',
                  ),
                ],
              ],
            ),
            SizedBox(height: compact ? 16 : 20),
            Row(
              children: [
                Expanded(
                  child: VButton(
                    text: 'Get Started',
                    icon: Icons.arrow_forward_rounded,
                    padding: EdgeInsets.symmetric(
                      vertical: compact ? 13 : 14,
                      horizontal: 16,
                    ),
                    onPressed: () async {
                      await onStart();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeVisualCard extends StatelessWidget {
  const _WelcomeVisualCard({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryAlt],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 22,
            compact ? 18 : 22,
            compact ? 18 : 22,
            compact ? 16 : 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ready to respond',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Mobile First',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Emergency tools, verification, and updates designed for fast action on your phone.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.4,
                ),
              ),
              SizedBox(height: compact ? 14 : 18),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 16 : 18),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadowPrimary,
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.shield_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'One tap access to alerts, reports, and identity verification.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Image.asset(
                              'lib/assets/images/ambulance.gif',
                              width: compact ? 190 : 230,
                              height: compact ? 190 : 230,
                            ),
                          ),
                        ),
                        const Row(
                          children: [
                            Expanded(
                              child: _VisualMetric(
                                value: 'Live',
                                label: 'Updates',
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _VisualMetric(
                                value: 'Fast',
                                label: 'Reporting',
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _VisualMetric(
                                value: 'Safe',
                                label: 'Access',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.backgroundAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VisualMetric extends StatelessWidget {
  const _VisualMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientBubble extends StatelessWidget {
  const _AmbientBubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
