import 'package:e_response_app_nemsu/controllers/VTextFieldController.dart';
import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/services/login_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/components/VButton.dart';
import 'package:e_response_app_nemsu/views/components/VIconButton.dart';
import 'package:e_response_app_nemsu/views/components/VTextField.dart';
import 'package:e_response_app_nemsu/views/components/VlLogo.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _redirectIfAuthenticated();
  }

  Future<void> _redirectIfAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('id');
    final fullname = prefs.getString('name');
    final token = prefs.getString('token');

    if (id != null &&
        id.isNotEmpty &&
        fullname != null &&
        fullname.isNotEmpty &&
        token != null &&
        token.isNotEmpty &&
        mounted) {
      Navigator.pushReplacementNamed(context, RouteManager.mainPage);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
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

    if (response['success']) {
      final status = response['data']['data']['status'];
      if (status == 'for_verification') {
        Navigator.pushNamed(context, RouteManager.verificationPage);
      } else if (status == 'pending_verification') {
        Navigator.pushNamed(context, RouteManager.for_verification_screen);
      } else {
        Navigator.pushReplacementNamed(context, RouteManager.mainPage);
      }
      return;
    }

    final message =
        response['message'] ?? 'Unable to login right now. Please try again.';
    _showError(message.toString());
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
              final bool compactHeight = constraints.maxHeight < 720;
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
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child:
                            isDesktop
                                ? _DesktopLoginShell(
                                  compactHeight: compactHeight,
                                  isLoading: _isLoading,
                                  emailController: emailController,
                                  passwordController: passwordController,
                                  onLogin: _login,
                                  onShowError: _showError,
                                )
                                : _MobileLoginShell(
                                  compactHeight: compactHeight,
                                  isLoading: _isLoading,
                                  emailController: emailController,
                                  passwordController: passwordController,
                                  onLogin: _login,
                                  onShowError: _showError,
                                ),
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
}

class _MobileLoginShell extends StatelessWidget {
  const _MobileLoginShell({
    required this.compactHeight,
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.onShowError,
  });

  final bool compactHeight;
  final bool isLoading;
  final VTextFieldController emailController;
  final VTextFieldController passwordController;
  final Future<void> Function() onLogin;
  final void Function(String message) onShowError;

  @override
  Widget build(BuildContext context) {
    if (compactHeight) {
      return _LoginFormCard(
        compactHeight: true,
        showSocial: false,
        isLoading: isLoading,
        emailController: emailController,
        passwordController: passwordController,
        onLogin: onLogin,
        onShowError: onShowError,
      );
    }

    return Column(
      children: [
        const Flexible(flex: 4, child: _MobileHeroCard(compactHeight: false)),
        const SizedBox(height: 14),
        Flexible(
          flex: 6,
          child: _LoginFormCard(
            compactHeight: false,
            showSocial: true,
            isLoading: isLoading,
            emailController: emailController,
            passwordController: passwordController,
            onLogin: onLogin,
            onShowError: onShowError,
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
    required this.onShowError,
  });

  final bool compactHeight;
  final bool isLoading;
  final VTextFieldController emailController;
  final VTextFieldController passwordController;
  final Future<void> Function() onLogin;
  final void Function(String message) onShowError;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _DesktopHeroCard(compactHeight: compactHeight)),
        const SizedBox(width: 20),
        Expanded(
          child: _LoginFormCard(
            compactHeight: compactHeight,
            showSocial: true,
            isLoading: isLoading,
            emailController: emailController,
            passwordController: passwordController,
            onLogin: onLogin,
            onShowError: onShowError,
          ),
        ),
      ],
    );
  }
}

class _MobileHeroCard extends StatelessWidget {
  const _MobileHeroCard({required this.compactHeight});

  final bool compactHeight;

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
            compactHeight ? 18 : 20,
            compactHeight ? 18 : 20,
            compactHeight ? 18 : 20,
            compactHeight ? 16 : 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  VLogo(size: 54, topSpacing: 0),
                ],
              ),
              SizedBox(height: compactHeight ? 10 : 12),
              Text(
                'Emergency access for fast mobile reporting.',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Log in to send reports, verify your account, and receive official emergency updates.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.35,
                ),
              ),
              const Spacer(),
              const Row(
                children: [
                  Expanded(
                    child: _HeroPill(
                      icon: Icons.location_on_outlined,
                      label: 'Reports',
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _HeroPill(
                      icon: Icons.campaign_outlined,
                      label: 'Alerts',
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _HeroPill(
                      icon: Icons.verified_user_outlined,
                      label: 'Access',
                    ),
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

class _DesktopHeroCard extends StatelessWidget {
  const _DesktopHeroCard({required this.compactHeight});

  final bool compactHeight;

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
            compactHeight ? 24 : 28,
            compactHeight ? 24 : 28,
            compactHeight ? 24 : 28,
            compactHeight ? 20 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Emergency Response Access',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: compactHeight ? 16 : 20),
              Text(
                'Secure coordination for reports, alerts, and verification.',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Access responder updates, submit urgent reports, and manage account verification from a single trusted emergency platform.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.45,
                ),
              ),
              SizedBox(height: compactHeight ? 18 : 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
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
                                width: 44,
                                height: 44,
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
                                  'Use the same portal for secure login, emergency reporting, and verification.',
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
                              width: compactHeight ? 210 : 250,
                              height: compactHeight ? 210 : 250,
                            ),
                          ),
                        ),
                        const Row(
                          children: [
                            Expanded(
                              child: _DesktopMetric(value: 'Fast', label: 'Reports'),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _DesktopMetric(value: 'Live', label: 'Alerts'),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _DesktopMetric(value: 'Safe', label: 'Access'),
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

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.compactHeight,
    required this.showSocial,
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.onShowError,
  });

  final bool compactHeight;
  final bool showSocial;
  final bool isLoading;
  final VTextFieldController emailController;
  final VTextFieldController passwordController;
  final Future<void> Function() onLogin;
  final void Function(String message) onShowError;

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
            Center(
              child: VLogo(size: compactHeight ? 70 : 72, topSpacing: 0),
            ),
            SizedBox(height: compactHeight ? 18 : 16),
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
              Row(
                children: [
                  Expanded(
                    child: VIconButton(
                      onPressed:
                          () =>
                              onShowError('Google login is not implemented yet.'),
                      text: 'Google',
                      icon: 'lib/assets/svg/google.svg',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: VIconButton(
                      onPressed:
                          () => onShowError(
                            'Facebook login is not implemented yet.',
                          ),
                      text: 'Facebook',
                      icon: 'lib/assets/svg/facebook.svg',
                    ),
                  ),
                ],
              ),
            ] else
              SizedBox(height: compactHeight ? 18 : 14),
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

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopMetric extends StatelessWidget {
  const _DesktopMetric({required this.value, required this.label});

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
