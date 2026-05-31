import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/components/press_scale.dart';
import 'package:flutter/material.dart';
import 'message_report_screen.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  void _openInAppVoiceCall(BuildContext context) {
    Navigator.pushNamed(context, RouteManager.call_screen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Emergency Report'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              // Fade + slide up the entire card on first build.
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 22 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Warning icon with a subtle bounce entrance
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.6, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutBack,
                          builder: (_, v, child) =>
                              Transform.scale(scale: v, child: child),
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              size: 38,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Report an Incident',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Choose the fastest way to contact responders. Use message reporting for details and images, or start an in-app voice call through the operations center (Twilio VoIP — not the phone dialer).',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.textMuted,
                                height: 1.4,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        // Message report button — animated press
                        PressScale(
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const MessageReportScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.message_outlined),
                              label: const Text('Send Message Report'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Voice call button — animated press
                        PressScale(
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _openInAppVoiceCall(context),
                              icon: const Icon(Icons.call_outlined),
                              label: const Text('Voice call (in-app)'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: const BorderSide(color: AppColors.accent),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
