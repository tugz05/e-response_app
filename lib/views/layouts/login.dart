import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:e_response_app_nemsu/controllers/VTextFieldController.dart';
import 'package:e_response_app_nemsu/helpers/account_session.dart';
import 'package:e_response_app_nemsu/helpers/app_mobile_role.dart';
import 'package:e_response_app_nemsu/helpers/google_profile_names.dart';
import 'package:e_response_app_nemsu/helpers/google_sign_in_support.dart';
import 'package:e_response_app_nemsu/helpers/login_payload.dart';
import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/services/google_sign_in_bootstrap.dart';
import 'package:e_response_app_nemsu/services/login_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/components/VButton.dart';
import 'package:e_response_app_nemsu/views/components/VIconButton.dart';
import 'package:e_response_app_nemsu/views/components/VTextField.dart';
import 'package:e_response_app_nemsu/views/components/VlLogo.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final VTextFieldController emailController = VTextFieldController();
  final VTextFieldController passwordController = VTextFieldController();
  final LoginService _loginService = LoginService();

  bool _isLoading = false;
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _redirectIfAuthenticated();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final initial = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isOffline = _noneConnected(initial));
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _isOffline = _noneConnected(results));
    });
  }

  static bool _noneConnected(List<ConnectivityResult> r) =>
      r.isEmpty || r.every((c) => c == ConnectivityResult.none);

  Future<void> _redirectIfAuthenticated() async {
    if (!mounted) {
      return;
    }
    await AccountSession.replaceRouteFromStoredCredentials(context);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showOfflineCallSheet() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OfflineCallSheet(onCall: _callNumber),
    );
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showError('Phone calling is not supported on this device.');
      }
    } catch (_) {
      _showError('Could not open the dialer. Call $number manually.');
    }
  }

  Future<void> _login() async {
    final email = emailController.textController.text.trim();
    final password = passwordController.textController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email/phone and password.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final response = await _loginService.login(email, password);

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });

    await _handleAuthResponse(response);
  }

  Future<void> _handleAuthResponse(Map<String, dynamic> response) async {
    try {
      if (response['success'] == true) {
        final outer = response['data'];
        if (outer is! Map) {
          _showError('Unexpected server response.');
          return;
        }
        final om = Map<String, dynamic>.from(outer);
        final innerData = om['data'];
        final Map<String, dynamic> userPayload;
        if (innerData is Map<String, dynamic>) {
          userPayload = LoginPayload.userMapFromDataObject(innerData);
        } else {
          userPayload = LoginPayload.userMapFromDataObject(om);
        }
        final status =
            AccountSession.normalizedStatusFromLoginPayload(userPayload);
        final roleFromPayload = AppMobileRole.parse(userPayload['app_role']);
        await AccountSession.replaceRouteForLoginStatus(
          context,
          status,
          roleFromPayload: roleFromPayload,
        );
        return;
      }

      final message =
          response['message'] ?? 'Unable to login right now. Please try again.';
      _showError(message.toString());
    } catch (e) {
      _showError('Could not process login response: $e');
    }
  }

  Future<void> _loginWithGoogle() async {
    if (!isGoogleSignInSupportedPlatform) {
      _showError('Google sign-in is not available on this platform.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await GoogleSignInBootstrap.ensureInitialized();

      late final GoogleSignInAccount account;
      try {
        account = await GoogleSignIn.instance.authenticate(
          scopeHint: const ['email', 'profile'],
        );
      } on GoogleSignInException catch (e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
        });
        // Android often reports [canceled] after account pick when OAuth is wrong
        // (SHA-1, package name, Web client ID) — was previously silent.
        if (e.code == GoogleSignInExceptionCode.canceled ||
            e.code == GoogleSignInExceptionCode.interrupted ||
            e.code == GoogleSignInExceptionCode.uiUnavailable) {
          _showError(
            'Google sign-in did not finish. Check Web client ID (strings.xml), '
            'debug/release SHA-1 in Google Cloud, and POST /api/v1/auth/google on your server.',
          );
          return;
        }
        if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
            e.code == GoogleSignInExceptionCode.providerConfigurationError) {
          _showError(
            e.description ??
                'Google Sign-In is misconfigured. Check Web client ID in strings.xml '
                'and your app SHA-1 / package name in Google Cloud.',
          );
          return;
        }
        _showError(e.description ?? e.toString());
        return;
      }

      if (!mounted) {
        return;
      }

      final GoogleSignInAuthentication auth = account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        _showError(
          'Could not obtain Google ID token. Set your Web OAuth client ID in '
          'GoogleSignInConfig or pass --dart-define=GOOGLE_SERVER_CLIENT_ID=...',
        );
        return;
      }

      final googleParsedName =
          GoogleParsedName.fromDisplayName(account.displayName);
      final Map<String, dynamic> response =
          await _loginService.loginWithGoogleIdToken(
        idToken,
        googleParsedName: googleParsedName,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      await _handleAuthResponse(response);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      _showError('Google sign-in failed: $e');
    }
  }

  void _showError(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final snack = SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: message.length > 100 ? 8 : 4),
      content: Text(message),
    );
    if (messenger != null) {
      messenger.showSnackBar(snack);
    } else {
      debugPrint('[LoginPage] $message');
    }
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
              final bool isDesktop = constraints.maxWidth >= 960;
              // Keyboard resize shrinks maxHeight; add insets so layout mode
              // does not flip while typing (avoids rebuilding fields / losing focus).
              final double stableBodyHeight =
                  constraints.maxHeight +
                  MediaQuery.viewInsetsOf(context).bottom;
              final bool compactHeight = stableBodyHeight < 720;
              final double padding = isDesktop ? 28 : 16;

              return Stack(
                children: [
                  const Positioned(
                    top: -70,
                    right: -35,
                    child: _AmbientBubble(size: 180, color: Color(0x2219336A)),
                  ),
                  const Positioned(
                    bottom: -50,
                    left: -20,
                    child: _AmbientBubble(size: 140, color: Color(0x160F766E)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(padding),
                    child: Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.manual,
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.viewInsetsOf(context).bottom + 12,
                          ),
                          child: isDesktop
                              ? _DesktopLoginShell(
                                  compactHeight: compactHeight,
                                  isLoading: _isLoading,
                                  emailController: emailController,
                                  passwordController: passwordController,
                                  onLogin: _login,
                                  onGoogleLogin: _loginWithGoogle,
                                )
                              : _MobileLoginShell(
                                  compactHeight: compactHeight,
                                  isLoading: _isLoading,
                                  emailController: emailController,
                                  passwordController: passwordController,
                                  onLogin: _login,
                                  onGoogleLogin: _loginWithGoogle,
                                ),
                        ),
                      ),
                    ),
                  ),
                  // ── Offline emergency call banner ─────────────────────────
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      transitionBuilder: (child, anim) => SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutCubic,
                        )),
                        child: child,
                      ),
                      child: _isOffline
                          ? _OfflineCallBanner(
                              key: const ValueKey('banner'),
                              onTap: _showOfflineCallSheet,
                            )
                          : const SizedBox.shrink(key: ValueKey('hidden')),
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
}

class _MobileLoginShell extends StatelessWidget {
  const _MobileLoginShell({
    required this.compactHeight,
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.onGoogleLogin,
  });

  final bool compactHeight;
  final bool isLoading;
  final VTextFieldController emailController;
  final VTextFieldController passwordController;
  final Future<void> Function() onLogin;
  final Future<void> Function() onGoogleLogin;

  @override
  Widget build(BuildContext context) {
    final double maxContent =
        (MediaQuery.sizeOf(context).width - 32).clamp(280.0, 440.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContent),
            child: _LoginHeroCard(compact: compactHeight),
          ),
        ),
        SizedBox(height: compactHeight ? 16 : 22),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContent),
            child: _LoginFormCard(
              compactHeight: compactHeight,
              showSocial: !compactHeight,
              showHeaderLogo: false,
              isLoading: isLoading,
              emailController: emailController,
              passwordController: passwordController,
              onLogin: onLogin,
              onGoogleLogin: onGoogleLogin,
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopLoginShell extends StatelessWidget {
  const _DesktopLoginShell({
    required this.compactHeight,
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.onGoogleLogin,
  });

  final bool compactHeight;
  final bool isLoading;
  final VTextFieldController emailController;
  final VTextFieldController passwordController;
  final Future<void> Function() onLogin;
  final Future<void> Function() onGoogleLogin;

  @override
  Widget build(BuildContext context) {
    const double maxContent = 460;

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _LoginHeroCard(compact: compactHeight),
            const SizedBox(height: 24),
            _LoginFormCard(
              compactHeight: compactHeight,
              showSocial: true,
              showHeaderLogo: false,
              isLoading: isLoading,
              emailController: emailController,
              passwordController: passwordController,
              onLogin: onLogin,
              onGoogleLogin: onGoogleLogin,
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered gradient hero above the login form.
class _LoginHeroCard extends StatelessWidget {
  const _LoginHeroCard({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = compact ? 20.0 : 26.0;
    final radius = BorderRadius.circular(compact ? 22 : 26);

    return Material(
      elevation: compact ? 6 : 10,
      shadowColor: AppColors.primary.withValues(alpha: 0.35),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryAlt],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad, pad + 2, pad, pad + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'lib/assets/images/logo.png',
                        width: compact ? 44 : 52,
                        height: compact ? 44 : 52,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 14 : 18),
                Text(
                  'Emergency access for fast mobile reporting',
                  textAlign: TextAlign.center,
                  style: (compact
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: compact ? 8 : 10),
                Text(
                  'Log in to send reports, verify your account, and receive official emergency updates.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.45,
                  ),
                ),
                SizedBox(height: compact ? 14 : 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _HeroFeatureChip(
                      icon: Icons.location_on_outlined,
                      label: 'Reports',
                    ),
                    _HeroFeatureChip(
                      icon: Icons.campaign_outlined,
                      label: 'Alerts',
                    ),
                    _HeroFeatureChip(
                      icon: Icons.verified_user_outlined,
                      label: 'Access',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _HeroFeatureChip extends StatelessWidget {
  const _HeroFeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.compactHeight,
    required this.showSocial,
    this.showHeaderLogo = true,
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.onGoogleLogin,
  });

  final bool compactHeight;
  final bool showSocial;
  final bool showHeaderLogo;
  final bool isLoading;
  final VTextFieldController emailController;
  final VTextFieldController passwordController;
  final Future<void> Function() onLogin;
  final Future<void> Function() onGoogleLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compactHeight ? 22 : 24,
          compactHeight ? 24 : 24,
          compactHeight ? 22 : 24,
          compactHeight ? 24 : 22,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              compactHeight
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
          children: [
            if (showHeaderLogo) ...[
              Center(
                child: VLogo(size: compactHeight ? 70 : 72, topSpacing: 0),
              ),
              SizedBox(height: compactHeight ? 18 : 16),
            ],
            Text(
              'Welcome back',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Log in to continue reporting incidents and receiving updates.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
            SizedBox(height: compactHeight ? 10 : 10),
            VTextField(
              hintText: 'Email or mobile number',
              headerText: 'Email / Phone',
              controller: emailController,
              textInputAction: TextInputAction.next,
              topPadding: compactHeight ? 14 : 18,
              headerBottomSpacing: compactHeight ? 8 : 8,
            ),
            VTextField(
              hintText: 'Enter your password',
              headerText: 'Password',
              isPassword: true,
              controller: passwordController,
              textInputAction: TextInputAction.done,
              topPadding: compactHeight ? 14 : 18,
              headerBottomSpacing: compactHeight ? 8 : 8,
              onSubmitted: (_) {
                if (!isLoading) {
                  onLogin();
                }
              },
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  Navigator.pushNamed(context, RouteManager.forgotPasswordPage);
                },
                child: const Text('Forgot password?'),
              ),
            ),
            SizedBox(height: compactHeight ? 12 : 8),
            VButton(
              text: 'Login',
              isLoading: isLoading,
              padding: EdgeInsets.symmetric(
                vertical: compactHeight ? 14 : 14,
                horizontal: 16,
              ),
              onPressed:
                  isLoading
                      ? () {}
                      : () async {
                        await onLogin();
                      },
            ),
            if (showSocial) ...[
              SizedBox(height: compactHeight ? 14 : 18),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'or continue with',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              VIconButton(
                onPressed:
                    isLoading
                        ? () {}
                        : () async {
                          await onGoogleLogin();
                        },
                text: 'Google',
                icon: 'lib/assets/svg/google.svg',
              ),
            ],
            SizedBox(height: compactHeight ? 18 : 20),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    "Don't have an account?",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, RouteManager.registerPage);
                    },
                    child: Text(
                      'Sign up',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Offline emergency-call widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Persistent red strip at the bottom of the screen, visible only when offline.
class _OfflineCallBanner extends StatelessWidget {
  const _OfflineCallBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFBF1C1C),
          boxShadow: [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No internet connection',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      'Tap to call the emergency hotline',
                      style: TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Call now',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet shown when the offline banner is tapped.
/// Presents Globe and Smart numbers for the user to choose from.
class _OfflineCallSheet extends StatelessWidget {
  const _OfflineCallSheet({required this.onCall});

  final Future<void> Function(String number) onCall;

  static const _globeNumber = '09567395623';
  static const _smartNumber = '09072993793';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(24, 18, 24, bottomPad + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Internet Connection',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Select a telecom to call the emergency hotline.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 18),

          Text(
            'EMERGENCY HOTLINES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 14),

          _OfflineCallOption(
            telecom: 'Globe',
            number: _globeNumber,
            color: const Color(0xFF0B4BB5),
            onTap: () => onCall(_globeNumber),
          ),
          const SizedBox(height: 10),
          _OfflineCallOption(
            telecom: 'Smart',
            number: _smartNumber,
            color: const Color(0xFFCC2020),
            onTap: () => onCall(_smartNumber),
          ),
        ],
      ),
    );
  }
}

/// A single telecom call option card inside [_OfflineCallSheet].
class _OfflineCallOption extends StatelessWidget {
  const _OfflineCallOption({
    required this.telecom,
    required this.number,
    required this.color,
    required this.onTap,
  });

  final String telecom;
  final String number;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Telecom icon badge
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.cell_tower_rounded,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Name + number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      telecom,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.1,
                      ),
                    ),
                    Text(
                      number,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              // Call button
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Call',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
