import 'package:e_response_app_nemsu/helpers/app_mobile_role.dart';
import 'package:e_response_app_nemsu/services/location_service.dart';
import 'package:e_response_app_nemsu/services/report_history_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/dashboard/list_news.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/dashboard/list_tips.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/content_ui.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/show_card.dart';
import 'package:e_response_app_nemsu/views/components/verification_selfie_avatar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with TickerProviderStateMixin {
  String userName = 'Responder';
  String greeting = 'Good Morning';
  String? _selfiePath;
  AppMobileRole _appRole = AppMobileRole.citizen;

  final ReportHistoryService _reportHistoryService = ReportHistoryService();
  bool _reportsLoading = false;
  String? _reportsError;
  bool _reportsIsOffline = false;
  List<Map<String, dynamic>> _homeReports = [];

  /// Bumps on pull-to-refresh so dashboard feeds remount and refetch from the API.
  int _feedRefreshGeneration = 0;

  bool _locationLoading = true;
  String? _locationText;
  String? _locationError;

  // ---------------------------------------------------------------------------
  // Single entrance animation — 7 sections staggered via Interval curves.
  // Replaces 7 individual AnimationControllers (_FadeSlideIn), reducing
  // Ticker overhead from 7 down to 1.
  // ---------------------------------------------------------------------------
  late final AnimationController _entranceCtrl;
  // Pre-built opacity and slide animations (indices 0–6 match build() order).
  final List<CurvedAnimation> _curvedAnims = [];
  final List<Animation<double>> _sectionOpacity = [];
  final List<Animation<Offset>> _sectionSlide = [];

  static const List<int> _sectionDelaysMs = [0, 80, 160, 230, 260, 310, 340];
  static const double _totalMs = 700.0;
  static const double _sectionDurationMs = 420.0;

  @override
  void initState() {
    super.initState();
    _buildEntranceAnimations();
    _loadUserName();
    _updateGreeting();
    _loadLocation();
  }

  void _buildEntranceAnimations() {
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    for (final delayMs in _sectionDelaysMs) {
      final start = delayMs / _totalMs;
      final end = ((delayMs + _sectionDurationMs) / _totalMs).clamp(0.0, 1.0);

      final opacityCurve = CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
      final slideCurve = CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.10),
        end: Offset.zero,
      ).animate(slideCurve);

      _curvedAnims
        ..add(opacityCurve)
        ..add(slideCurve);
      _sectionOpacity.add(opacityCurve);
      _sectionSlide.add(slide);
    }

    // Kick off after the first frame so the screen is laid out first.
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    for (final a in _curvedAnims) {
      a.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      userName = prefs.getString('name') ?? 'Responder';
      _selfiePath = prefs.getString('img_selfie');
      _appRole = AppMobileRole.fromPrefs(prefs);
    });
    await _loadReportHistory(prefs);
  }

  Future<void> _loadReportHistory([SharedPreferences? existing]) async {
    final prefs = existing ?? await SharedPreferences.getInstance();
    final uid = prefs.getString('id') ?? '';
    final token = prefs.getString('token');

    if (!mounted) {
      return;
    }
    setState(() {
      _reportsLoading = true;
      _reportsError = null;
    });

    final result = await _reportHistoryService.fetchForUser(
      uid,
      bearerToken: token,
    );

    if (!mounted) {
      return;
    }

    if (!result.isSuccess) {
      setState(() {
        _reportsLoading = false;
        _reportsError = result.errorMessage;
        _reportsIsOffline = result.isOffline;
        _homeReports = [];
      });
      return;
    }

    final items = result.items ?? [];
    setState(() {
      _reportsLoading = false;
      _reportsError = null;
      _reportsIsOffline = false;
      _homeReports = items.take(3).toList();
    });
  }

  Future<void> _loadLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
      _locationText = null;
    });
    try {
      final address = await LocationService.getCurrentAddress();
      if (!mounted) {
        return;
      }
      setState(() {
        _locationText = address;
        _locationLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationLoading = false;
        _locationError =
            'Turn on location services and allow access to see your area here.';
      });
    }
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    setState(() {
      if (hour < 12) {
        greeting = 'Good Morning';
      } else if (hour < 18) {
        greeting = 'Good Afternoon';
      } else {
        greeting = 'Good Evening';
      }
    });
  }

  String _todayLabel() {
    return DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
  }

  Widget _heroLocationBanner(ThemeData theme) {
    final subtle = Colors.white.withValues(alpha: 0.88);
    final muted = Colors.white.withValues(alpha: 0.62);

    Widget refreshBtn({EdgeInsetsGeometry? padding}) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        padding: padding ?? EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        tooltip: 'Refresh location',
        onPressed: _locationLoading ? null : _loadLocation,
        icon: Icon(Icons.refresh_rounded, color: subtle, size: 22),
      );
    }

    if (_locationLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: subtle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Getting your location…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: subtle,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_locationError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.location_off_outlined, color: muted, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location unavailable',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _locationError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            refreshBtn(),
          ],
        ),
      );
    }

    final text = _locationText ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR LOCATION',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          refreshBtn(padding: const EdgeInsets.only(left: 4)),
        ],
      ),
    );
  }

  String _formatReportDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d · h:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Color _reportStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'pending') {
      return AppColors.warning;
    }
    if (s == 'completed') {
      return AppColors.success;
    }
    return AppColors.textMuted;
  }

  Widget _compactReportTile(
    ThemeData theme,
    Map<String, dynamic> tx,
    TextStyle? muted,
  ) {
    final type = tx['type'] ?? 'Report';
    final status = tx['status'] ?? 'N/A';
    final details = tx['details']?.toString() ?? '';
    final reportAddress = tx['address']?.toString() ?? '';
    final createdAt = tx['created_at']?.toString() ?? '';
    final secondary = details.isNotEmpty ? details : reportAddress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            type.toString().toLowerCase() == 'message'
                ? Icons.message_outlined
                : Icons.call_outlined,
            color: AppColors.primary.withValues(alpha: 0.75),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        type.toString(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      status.toString(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _reportStatusColor(status.toString()),
                      ),
                    ),
                  ],
                ),
                if (secondary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  _formatReportDate(createdAt),
                  style: muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeReportHistorySection(ThemeData theme) {
    final muted = theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: AppColors.primary.withValues(alpha: 0.45),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recent reports',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'See Profile',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_reportsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (_reportsError != null)
            _ReportsErrorState(
              isOffline: _reportsIsOffline,
              message: _reportsError!,
              onRetry: _loadReportHistory,
            )
          else if (_homeReports.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                'No reports yet. Tap Report below when you need assistance.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < _homeReports.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.dividerColor.withValues(alpha: 0.35),
                    ),
                  _compactReportTile(
                    theme,
                    _homeReports[i],
                    muted,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: () async {
          _updateGreeting();
          await Future.wait([_loadUserName(), _loadLocation()]);
          if (mounted) {
            setState(() => _feedRefreshGeneration++);
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            // Section 0 — greeting row
            FadeTransition(
              opacity: _sectionOpacity[0],
              child: SlideTransition(
                position: _sectionSlide[0],
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    VerificationSelfieAvatar(
                      displayName: userName,
                      selfiePath: _selfiePath,
                      radius: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting, $userName',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _todayLabel(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Section 1 — hero card
            FadeTransition(
              opacity: _sectionOpacity[1],
              child: SlideTransition(
                position: _sectionSlide[1],
                child: ShowCard(
                  locationSection: _heroLocationBanner(theme),
                  appRole: _appRole,
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Section 2 — recent reports
            FadeTransition(
              opacity: _sectionOpacity[2],
              child: SlideTransition(
                position: _sectionSlide[2],
                child: _homeReportHistorySection(theme),
              ),
            ),
            const SizedBox(height: 18),
            // Section 3 — preparedness header
            FadeTransition(
              opacity: _sectionOpacity[3],
              child: SlideTransition(
                position: _sectionSlide[3],
                child: ContentSectionHeader(
                  title: 'Preparedness',
                  trailing: Icon(
                    Icons.health_and_safety_outlined,
                    color: AppColors.primary.withValues(alpha: 0.45),
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Section 4 — preparedness feed
            FadeTransition(
              opacity: _sectionOpacity[4],
              child: SlideTransition(
                position: _sectionSlide[4],
                child: ListTipsDashboard(
                  key: ValueKey<int>(_feedRefreshGeneration),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Section 5 — news header
            FadeTransition(
              opacity: _sectionOpacity[5],
              child: SlideTransition(
                position: _sectionSlide[5],
                child: ContentSectionHeader(
                  title: 'Latest news',
                  trailing: Icon(
                    Icons.newspaper_rounded,
                    color: AppColors.primary.withValues(alpha: 0.45),
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Section 6 — news feed
            FadeTransition(
              opacity: _sectionOpacity[6],
              child: SlideTransition(
                position: _sectionSlide[6],
                child: ListNewsDashboard(
                  key: ValueKey<int>(_feedRefreshGeneration),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact error state for the Recent Reports card.
// Shows a distinct offline vs server-error appearance.
// ---------------------------------------------------------------------------

class _ReportsErrorState extends StatelessWidget {
  const _ReportsErrorState({
    required this.isOffline,
    required this.message,
    required this.onRetry,
  });

  final bool isOffline;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isOffline ? AppColors.warning : AppColors.accent;
    final icon = isOffline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded;
    final title = isOffline ? 'No connection' : 'Could not load';
    final body = isOffline
        ? 'Check your internet connection and try again.'
        : message;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                textStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }
}

