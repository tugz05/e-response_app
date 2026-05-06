import 'package:e_response_app_nemsu/helpers/account_session.dart';
import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/components/VButton.dart';
import 'package:flutter/material.dart';

class VerifyAccountScreen extends StatelessWidget {
  const VerifyAccountScreen({super.key});

  Future<void> _exitToLogin(BuildContext context) async {
    await AccountSession.deferNextPendingVerificationAutoRoute();
    if (!context.mounted) {
      return;
    }
    final didPop = await Navigator.maybePop(context);
    if (!didPop && context.mounted) {
      Navigator.of(context).pushReplacementNamed(RouteManager.loginPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight -
                      MediaQuery.paddingOf(context).vertical -
                      40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 5,
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
                            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                tooltip: 'Close',
                                onPressed: () => _exitToLogin(context),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textMuted.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              24,
                              0,
                              24,
                              28,
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.schedule_rounded,
                                    color: AppColors.primary,
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'VERIFICATION IN PROGRESS',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "We're verifying your account",
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundAlt,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 22,
                                        color: AppColors.primary.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'What happens next',
                                              style: theme
                                                  .textTheme.titleSmall
                                                  ?.copyWith(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                                height: 1.25,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Your registration is under review. '
                                              'If we need more information, you’ll '
                                              'be asked to complete identity '
                                              'verification. Otherwise, our team '
                                              'will finish checking your details.',
                                              style: theme
                                                  .textTheme.bodyMedium
                                                  ?.copyWith(
                                                color: AppColors.textMuted,
                                                height: 1.5,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'You will receive access to the full workspace '
                                  'once verification is approved.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMuted,
                                    height: 1.45,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 28),
                                VButton(
                                  onPressed: () => _exitToLogin(context),
                                  text: 'Back to login',
                                  icon: Icons.arrow_back_rounded,
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
            );
          },
        ),
      ),
    );
  }
}
