import 'dart:async';
import 'dart:ui';

import 'package:e_response_app_nemsu/views/components/press_scale.dart';
import 'package:e_response_app_nemsu/helpers/account_session.dart';
import 'package:e_response_app_nemsu/helpers/logout.dart';
import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/helpers/permission_settings.dart';
import 'package:e_response_app_nemsu/services/twilio_service.dart';
import 'package:e_response_app_nemsu/services/shared_preferences/SharedPreferencesService.dart';
import 'package:e_response_app_nemsu/helpers/app_mobile_role.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/staff/staff_app_shell.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/staff/staff_voice_bridge.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/dashboard.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/pages.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/tips.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/user.dart';
import 'package:flutter/material.dart';

const Duration _kBottomNavMotionDuration = Duration(milliseconds: 320);
const Curve _kBottomNavMotionCurve = Curves.easeInOutCubicEmphasized;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const Color _navBarBlue = AppColors.primary;

  final SharedPreferencesService _prefsService = SharedPreferencesService();
  Timer? _inactivityTimer;
  int _currentIndex = 0;
  bool _isExpanded = false;
  AppMobileRole _role = AppMobileRole.citizen;
  List<Widget> _pages = [];
  List<_NavItemData> _navItems = [];

  @override
  void initState() {
    super.initState();
    // Native Twilio plugin drops events when EventChannel has no listener yet.
    TwilioService().ensureCallEventsDelivered();
    _syncPagesWithRole(AppMobileRole.citizen);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      AccountSession.guardAuthenticatedShell(context);
      await _reloadStoredAppRole();
    });
    _loadCredentials();
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    final creds = await _prefsService.getCredentials();
    final token = creds['token'];
    final result = await TwilioService().init(bearerToken: token);

    // When microphone is permanently denied the Twilio SDK cannot init.
    // Guide the user to Settings — nothing else can be done at runtime.
    if (!result.ok && mounted) {
      final msg = result.failureMessage ?? '';
      if (msg.toLowerCase().contains('microphone')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Microphone Access Required'),
              content: const Text(
                'Microphone permission was denied. Emergency voice calls '
                'require microphone access.\n\n'
                'Please open Settings and allow microphone access for this app.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Later'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openPermissionSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        });
      }
    }

    // AppPushService.initialize() already calls syncTokenWithBackendIfPossible()
    // at the end of its own setup — no need to call it again here.
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(days: 7), () {
      LogoutModule.performLogout(context);
    });
  }

  Future<void> _reloadStoredAppRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    final role = AppMobileRole.fromPrefs(prefs);
    setState(() {
      _syncPagesWithRole(role);
      if (role.canAccessIncidentWorkspace) {
        _currentIndex = 0;
      } else {
        _currentIndex = _currentIndex.clamp(0, _pages.length - 1);
      }
    });
  }

  void _syncPagesWithRole(AppMobileRole role) {
    _role = role;
    final responderWorkspace = role.canAccessIncidentWorkspace;
    if (responderWorkspace) {
      _pages = [];
      _navItems = [];
      return;
    }
    _pages = [
      const Dashboard(),
      const Pages(
        apiUrl: 'api/v1/news',
        titleText: 'Latest News',
        subtitleText:
            'Official announcements, service updates, and situational advisories.',
        icon: Icons.newspaper_outlined,
      ),
      const TipsPage(),
      const UserPage(),
    ];
    _navItems = [
      const _NavItemData(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      const _NavItemData(
        label: 'News',
        icon: Icons.newspaper_outlined,
        selectedIcon: Icons.newspaper_rounded,
      ),
      const _NavItemData(
        label: 'Tips',
        icon: Icons.lightbulb_outline_rounded,
        selectedIcon: Icons.lightbulb_rounded,
      ),
      const _NavItemData(
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_role.canAccessIncidentWorkspace) {
      // Use [Listener] so inactivity tracking does not compete with child taps
      // ([InkWell], [PopupMenuButton], etc.) in the gesture arena.
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _resetInactivityTimer(),
        child: StaffVoiceBridge(
          onUserActivity: _resetInactivityTimer,
          child: StaffAppShell(onUserActivity: _resetInactivityTimer),
        ),
      );
    }

    return GestureDetector(
      onTap: _resetInactivityTimer,
      onPanDown: (_) => _resetInactivityTimer(),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double navHeight = _BottomActionNavBar.totalHeightFor(
                context,
              );

              return Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: navHeight - 12),
                      child: IndexedStack(
                        index: _currentIndex,
                        children: _pages,
                      ),
                    ),
                  ),
                  if (_isExpanded)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isExpanded = false;
                          });
                        },
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: navHeight + 6,
                    child: IgnorePointer(
                      ignoring: !_isExpanded,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _QuickReportAction(
                            icon: Icons.call,
                            label: 'Call',
                            color: AppColors.accent,
                            isVisible: _isExpanded,
                            entranceDelay: Duration.zero,
                            onTap: () {
                              setState(() => _isExpanded = false);
                              Navigator.pushNamed(
                                context,
                                RouteManager.call_screen,
                              );
                            },
                          ),
                          const SizedBox(width: 14),
                          _QuickReportAction(
                            icon: Icons.message,
                            label: 'Message',
                            color: AppColors.secondary,
                            isVisible: _isExpanded,
                            entranceDelay: const Duration(milliseconds: 65),
                            onTap: () {
                              setState(() => _isExpanded = false);
                              Navigator.pushNamed(
                                context,
                                RouteManager.message_report_screen,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomActionNavBar(
                      items: _navItems,
                      currentIndex: _currentIndex,
                      navBarColor: _navBarBlue,
                      isExpanded: _isExpanded,
                      onItemSelected: (index) {
                        setState(() {
                          _currentIndex = index;
                          _isExpanded = false;
                        });
                      },
                      onPrimaryActionTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
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

class _NavItemData {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavItemData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class _BottomActionNavBar extends StatelessWidget {
  final List<_NavItemData> items;
  final int currentIndex;
  final bool isExpanded;
  final Color navBarColor;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onPrimaryActionTap;

  const _BottomActionNavBar({
    required this.items,
    required this.currentIndex,
    required this.isExpanded,
    required this.navBarColor,
    required this.onItemSelected,
    required this.onPrimaryActionTap,
  });

  static double totalHeightFor(BuildContext context) {
    return 122 + MediaQuery.paddingOf(context).bottom;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: totalHeightFor(context),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Container(
              height: 94 + bottomInset,
              decoration: BoxDecoration(
                color: navBarColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: navBarColor.withValues(alpha: 0.28),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 10 + bottomInset),
                child: Row(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      if (index == 2) const SizedBox(width: 92),
                      Expanded(
                        child: _BottomNavItem(
                          item: items[index],
                          isSelected: currentIndex == index,
                          onTap: () => onItemSelected(index),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 10,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: isExpanded ? 1 : 0),
              duration: _kBottomNavMotionDuration,
              curve: _kBottomNavMotionCurve,
              builder: (context, value, child) {
                final double scale = lerpDouble(1, 1.08, value) ?? 1;
                final double blur = lerpDouble(16, 22, value) ?? 16;
                final double shadowOffset = lerpDouble(8, 11, value) ?? 8;

                return Transform.scale(
                  scale: scale,
                  child: GestureDetector(
                    onTap: onPrimaryActionTap,
                    child: AnimatedContainer(
                      duration: _kBottomNavMotionDuration,
                      curve: _kBottomNavMotionCurve,
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Color.lerp(navBarColor, AppColors.accent, value),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: blur,
                            offset: Offset(0, shadowOffset),
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.82,
                                  end: 1,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Transform.rotate(
                            key: ValueKey<bool>(isExpanded),
                            angle: (lerpDouble(0, 0.32, value) ?? 0),
                            child: Icon(
                              isExpanded
                                  ? Icons.close_rounded
                                  : Icons.campaign_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final _NavItemData item;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isSelected ? Colors.white : Colors.white70;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.18 : 1.0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: foregroundColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickReportAction extends StatefulWidget {
  const _QuickReportAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.isVisible,
    required this.entranceDelay,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isVisible;
  final Duration entranceDelay;

  @override
  State<_QuickReportAction> createState() => _QuickReportActionState();
}

class _QuickReportActionState extends State<_QuickReportAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _scaleAnim =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _opacityAnim =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    if (widget.isVisible) {
      Future.delayed(widget.entranceDelay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _QuickReportAction old) {
    super.didUpdateWidget(old);
    if (widget.isVisible && !old.isVisible) {
      _ctrl.reset();
      Future.delayed(widget.entranceDelay, () {
        if (mounted) _ctrl.forward();
      });
    } else if (!widget.isVisible && old.isVisible) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: FadeTransition(
        opacity: _opacityAnim,
        child: PressScale(
          scale: 0.93,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.14),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(24),
              child: Ink(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          widget.color.withValues(alpha: 0.15),
                      child: Icon(widget.icon, color: widget.color, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
