import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/services/report_history_service.dart';
import 'package:e_response_app_nemsu/services/shared_preferences/SharedPreferencesService.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/pages.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/staff/citizen_report_detail_page.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/staff/situational_incident_report_form_args.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/staff/situational_incident_reports_list_page.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/user.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Operations console for staff/admin: citizen call & message reports with a
/// calmer layout than the citizen floating-nav shell.
class StaffAppShell extends StatefulWidget {
  const StaffAppShell({super.key, required this.onUserActivity});

  final VoidCallback onUserActivity;

  @override
  State<StaffAppShell> createState() => _StaffAppShellState();
}

class _StaffAppShellState extends State<StaffAppShell> {
  int _index = 0;

  late final List<Widget> _pages = [
    const StaffDispatchPage(),
    const SituationalIncidentReportsListPage(embedInStaffShell: true),
    const Pages(
      apiUrl: 'api/v1/news',
      titleText: 'Operational briefings',
      subtitleText:
          'Official advisories and announcements relevant to response teams.',
      icon: Icons.newspaper_outlined,
    ),
    const UserPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onUserActivity,
      onPanDown: (_) => widget.onUserActivity(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F4F9),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey<int>(_index),
            child: _pages[_index],
          ),
        ),
        bottomNavigationBar: Material(
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          color: Colors.white,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: NavigationBar(
                height: 64,
                elevation: 0,
                backgroundColor: Colors.transparent,
                indicatorColor: AppColors.primary.withValues(alpha: 0.14),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                selectedIndex: _index,
                onDestinationSelected: (i) {
                  widget.onUserActivity();
                  setState(() => _index = i);
                },
                destinations: [
                  NavigationDestination(
                    icon: Icon(
                      Icons.grid_view_rounded,
                      color:
                          _index == 0
                              ? AppColors.primary
                              : AppColors.textMuted,
                    ),
                    selectedIcon: Icon(
                      Icons.grid_view_rounded,
                      color: AppColors.primary,
                    ),
                    label: 'Dispatch',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.fact_check_rounded,
                      color:
                          _index == 1
                              ? AppColors.primary
                              : AppColors.textMuted,
                    ),
                    selectedIcon: Icon(
                      Icons.fact_check_rounded,
                      color: AppColors.primary,
                    ),
                    label: 'Incidents',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.article_outlined,
                      color:
                          _index == 2
                              ? AppColors.primary
                              : AppColors.textMuted,
                    ),
                    selectedIcon: Icon(
                      Icons.article_rounded,
                      color: AppColors.primary,
                    ),
                    label: 'Briefings',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.person_outline_rounded,
                      color:
                          _index == 3
                              ? AppColors.primary
                              : AppColors.textMuted,
                    ),
                    selectedIcon: Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                    ),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _DispatchFilter { all, call, message }

/// Citizen call/message aggregate for dispatchers.
class StaffDispatchPage extends StatefulWidget {
  const StaffDispatchPage({super.key});

  @override
  State<StaffDispatchPage> createState() => _StaffDispatchPageState();
}

class _StaffDispatchPageState extends State<StaffDispatchPage> {
  final _history = ReportHistoryService();
  final _prefs = SharedPreferencesService();

  _DispatchFilter _filter = _DispatchFilter.all;
  String _searchText = '';
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final creds = await _prefs.getCredentials();
    final token = creds['token'] ?? '';
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Session expired.';
        _items = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _history.fetchAllForStaff(bearerToken: token);

    if (!mounted) {
      return;
    }

    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _error = result.errorMessage;
        _items = [];
      });
      return;
    }

    final raw = List<Map<String, dynamic>>.from(result.items ?? []);
    raw.sort((a, b) {
      final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime(1970);
      final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime(1970);
      return db.compareTo(da);
    });

    setState(() {
      _loading = false;
      _items = raw;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case _DispatchFilter.all:
        return _items;
      case _DispatchFilter.call:
        return _items
            .where(
              (e) => (e['type'] ?? '').toString().toLowerCase() != 'message',
            )
            .toList();
      case _DispatchFilter.message:
        return _items
            .where(
              (e) => (e['type'] ?? '').toString().toLowerCase() == 'message',
            )
            .toList();
    }
  }

  List<Map<String, dynamic>> get _searchFiltered {
    final q = _searchText.trim().toLowerCase();
    if (q.isEmpty) {
      return _filtered;
    }
    return _filtered.where((tx) => _citizenRowMatchesSearch(tx, q)).toList();
  }

  bool _citizenRowMatchesSearch(Map<String, dynamic> tx, String q) {
    final blobs = <String?>[
      _reporterLine(tx),
      tx['details']?.toString(),
      tx['address']?.toString(),
      tx['status']?.toString(),
      tx['type']?.toString(),
    ];
    for (final s in blobs) {
      if (s != null && s.toLowerCase().contains(q)) {
        return true;
      }
    }
    return false;
  }

  String _reporterLine(Map<String, dynamic> tx) {
    final parts = <String>[];
    final name =
        tx['user_name'] ??
        tx['citizen_name'] ??
        tx['name'] ??
        (tx['user'] is Map ? (tx['user'] as Map)['name'] : null);
    if (name != null && name.toString().trim().isNotEmpty) {
      parts.add(name.toString().trim());
    }
    final uid = tx['user_id'] ?? tx['userId'];
    if (uid != null) {
      parts.add('ID $uid');
    }
    return parts.isEmpty ? 'Citizen reporter' : parts.join(' · ');
  }

  Future<void> _openSituational(Map<String, dynamic> tx) async {
    await Navigator.of(context, rootNavigator: true).pushNamed(
      RouteManager.situationalIncidentReportForm,
      arguments: SituationalIncidentReportFormArgs(
        citizenReportPrefill: Map<String, dynamic>.from(tx),
      ),
    );
  }

  Future<void> _openCitizenDetail(Map<String, dynamic> tx) async {
    final rawId = tx['id'];
    final id =
        rawId is int ? rawId : int.tryParse(rawId?.toString().trim() ?? '');
    if (id == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This row has no report id — cannot load from the server.',
          ),
        ),
      );
      return;
    }
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (ctx) => CitizenReportDetailPage(reportId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OPERATIONS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Citizen reports',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Live call and message intake across registered users. '
                    'Open a row to draft a situational incident record.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    onChanged: (v) => setState(() => _searchText = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search by name, details, address, status…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.65),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _filter == _DispatchFilter.all,
                          onTap:
                              () => setState(() => _filter = _DispatchFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Calls',
                          selected: _filter == _DispatchFilter.call,
                          onTap:
                              () =>
                                  setState(() => _filter = _DispatchFilter.call),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Messages',
                          selected: _filter == _DispatchFilter.message,
                          onTap:
                              () => setState(
                                () => _filter = _DispatchFilter.message,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading && _items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 52,
                      color: AppColors.textMuted.withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_searchFiltered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _items.isEmpty
                        ? 'No citizen reports in the queue.'
                        : 'Nothing matches this filter or search.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverList.separated(
                itemCount: _searchFiltered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final tx = _searchFiltered[i];
                  return _DispatchReportCard(
                    tx: tx,
                    reporterLine: _reporterLine(tx),
                    onOpenDetail: () => _openCitizenDetail(tx),
                    onOpenSituational: () => _openSituational(tx),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DispatchReportCard extends StatelessWidget {
  const _DispatchReportCard({
    required this.tx,
    required this.reporterLine,
    required this.onOpenDetail,
    required this.onOpenSituational,
  });

  final Map<String, dynamic> tx;
  final String reporterLine;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenSituational;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = (tx['type'] ?? '').toString();
    final isMessage = type.toLowerCase() == 'message';
    final accent = isMessage ? AppColors.secondary : AppColors.accent;
    final status = (tx['status'] ?? '—').toString();
    final details = (tx['details'] ?? '').toString();
    final address = (tx['address'] ?? '').toString();
    final createdRaw = tx['created_at']?.toString();
    DateTime? dt;
    if (createdRaw != null) {
      dt = DateTime.tryParse(createdRaw);
    }
    final timeLabel =
        dt != null
            ? '${DateFormat('MMM d, y').format(dt.toLocal())} · ${DateFormat.jm().format(dt.toLocal())}'
            : (createdRaw ?? '—');

    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetail,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(17),
                      bottomLeft: Radius.circular(17),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isMessage ? 'MESSAGE' : 'CALL',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textMuted.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          reporterLine,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          timeLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            details,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.92,
                              ),
                            ),
                          ),
                        ],
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMuted,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _StatusPill(status: status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: 16,
                              color: AppColors.primary.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tap card for full intake',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _DraftSituationalCtaButton(
                          accent: accent,
                          onPressed: onOpenSituational,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary action — high contrast, gradient, clear affordance.
class _DraftSituationalCtaButton extends StatelessWidget {
  const _DraftSituationalCtaButton({
    required this.accent,
    required this.onPressed,
  });

  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                Color.lerp(AppColors.primary, accent, 0.35)!,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Draft situational report',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Structured CDRRMO form · Pre-filled from this intake',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.95),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg = AppColors.primarySoft;
    Color fg = AppColors.primary;
    if (s == 'pending') {
      bg = AppColors.warning.withValues(alpha: 0.15);
      fg = AppColors.warning;
    } else if (s == 'completed') {
      bg = AppColors.success.withValues(alpha: 0.14);
      fg = AppColors.success;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: fg,
        ),
      ),
    );
  }
}
