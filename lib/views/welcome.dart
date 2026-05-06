import 'package:e_response_app_nemsu/helpers/account_session.dart';
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
      await AccountSession.replaceRouteFromStoredCredentials(context);
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pad = constraints.maxWidth >= 600 ? 32.0 : 20.0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(pad, 20, pad, 16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 4,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primaryAlt,
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  28,
                                  24,
                                  24,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Center(
                                      child: VLogo(size: 64, topSpacing: 0),
                                    ),
                                    const SizedBox(height: 22),
                                    Text(
                                      'OFFICIAL RESPONSE APP',
                                      textAlign: TextAlign.center,
                                      style:
                                          theme.textTheme.labelMedium?.copyWith(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.85,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Welcome',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Submit incident reports, share your '
                                      'location when it matters, and follow '
                                      'official updates from response teams.',
                                      textAlign: TextAlign.center,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: AppColors.textMuted,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    VButton(
                                      text: 'Get Started',
                                      icon: Icons.arrow_forward_rounded,
                                      onPressed: () async {
                                        await _setFirstTime();
                                        if (!context.mounted) {
                                          return;
                                        }
                                        Navigator.pushReplacementNamed(
                                          context,
                                          RouteManager.loginPage,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 8),
                  child: const Footer(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
