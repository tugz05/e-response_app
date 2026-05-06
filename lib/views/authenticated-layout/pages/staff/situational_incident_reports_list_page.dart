import 'package:e_response_app_nemsu/models/situational_incident_report.dart';
import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/services/shared_preferences/SharedPreferencesService.dart';
import 'package:e_response_app_nemsu/services/situational_incident_report_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/staff/situational_incident_report_form_args.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Lists situational incident reports for the signed-in user when they have
/// staff/rescuer or administrator mobile access.
class SituationalIncidentReportsListPage extends StatefulWidget {
  const SituationalIncidentReportsListPage({
    super.key,
    this.embedInStaffShell = false,
  });

  /// Hides the FAB and matches the staff shell chrome when true.
  final bool embedInStaffShell;

  @override
  State<SituationalIncidentReportsListPage> createState() =>
      _SituationalIncidentReportsListPageState();
}

class _SituationalIncidentReportsListPageState
    extends State<SituationalIncidentReportsListPage> {
  final _service = SituationalIncidentReportService();
  final _prefs = SharedPreferencesService();

  List<SituationalIncidentReport> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final creds = await _prefs.getCredentials();
    final uid = creds['id'] ?? '';
    final token = creds['token'] ?? '';
    if (uid.isEmpty || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Not signed in.';
        _items = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _service.fetchHistory(uid, bearerToken: token);

    if (!mounted) {
      return;
    }

    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _error = result.failureSnackText('Failed to load history');
        _items = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.failureSnackText('Failed to load history')),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _loading = false;
      _items = List<SituationalIncidentReport>.from(result.data ?? []);
    });
  }

  /// Staff shell embeds this tab without an inner [Navigator]; use root routes.
  Future<T?> _pushNamed<T>(String route, {Object? arguments}) {
    return Navigator.of(context, rootNavigator: true).pushNamed<T>(
      route,
      arguments: arguments,
    );
  }

  String _dateSubtitle(SituationalIncidentReport r) {
    if (r.dateTimeReceived == null) {
      return 'No timestamp';
    }
    final local = r.dateTimeReceived!.toLocal();
    return '${DateFormat('MMM d, y').format(local)} · ${DateFormat.jm().format(local)}';
  }

  Future<void> _openDetail(SituationalIncidentReport r) async {
    final id = r.id;
    if (id == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This record has no server id yet — pull to refresh or contact support.',
          ),
        ),
      );
      return;
    }
    final changed = await _pushNamed<bool>(
      RouteManager.situationalIncidentReportDetail,
      arguments: id,
    );
    if (!mounted) {
      return;
    }
    if (changed == true) {
      _load();
    }
  }

  Future<void> _openEdit(SituationalIncidentReport r) async {
    final id = r.id;
    if (id == null) {
      return;
    }
    final changed = await _pushNamed<bool>(
      RouteManager.situationalIncidentReportForm,
      arguments: SituationalIncidentReportFormArgs(existingId: id),
    );
    if (!mounted) {
      return;
    }
    if (changed == true) {
      _load();
    }
  }

  Future<void> _confirmDelete(SituationalIncidentReport r) async {
    final id = r.id;
    if (id == null) {
      return;
    }
    final creds = await _prefs.getCredentials();
    final token = creds['token'] ?? '';
    if (!mounted || token.isEmpty) {
      return;
    }

    final ok =
        await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Delete report?'),
                content: Text(
                  'Remove "${r.incidentType ?? 'Incident #$id'}" permanently?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!ok || !mounted) {
      return;
    }

    final result = await _service.delete(id, bearerToken: token);
    if (!mounted) {
      return;
    }

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.failureSnackText('Delete failed')),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report deleted.')),
    );
    _load();
  }

  Future<void> _openNewReport() async {
    await _pushNamed(
      RouteManager.situationalIncidentReportForm,
      arguments: const SituationalIncidentReportFormArgs(),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg =
        widget.embedInStaffShell
            ? const Color(0xFFF1F4F9)
            : AppColors.background;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedInStaffShell,
        elevation: widget.embedInStaffShell ? 0 : null,
        backgroundColor:
            widget.embedInStaffShell ? Colors.transparent : AppColors.primary,
        foregroundColor: widget.embedInStaffShell ? AppColors.textPrimary : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.embedInStaffShell
                  ? 'Situational incidents'
                  : 'Incident reports',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'CDRRMO structured records',
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    widget.embedInStaffShell
                        ? AppColors.textMuted
                        : Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New report',
            onPressed: _openNewReport,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton:
          widget.embedInStaffShell
              ? null
              : FloatingActionButton.extended(
                onPressed: _openNewReport,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New report'),
              ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 16),
          Center(
            child: Text(
              'Loading incident records…',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Icon(Icons.error_outline_rounded, size: 48, color: AppColors.accent),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fact_check_rounded,
                size: 40,
                color: AppColors.primary.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No incident reports on file',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.embedInStaffShell
                ? 'Create a formal situational record from the actions above.'
                : 'Tap “New report” to file a CDRRMO situational incident report.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _openNewReport,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create first report'),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        widget.embedInStaffShell ? 32 : 100,
      ),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = _items[i];
        return _IncidentReportListCard(
          report: r,
          dateLabel: _dateSubtitle(r),
          onOpen: () => _openDetail(r),
          onEdit: () => _openEdit(r),
          onDelete: () => _confirmDelete(r),
        );
      },
    );
  }
}

class _IncidentReportListCard extends StatelessWidget {
  const _IncidentReportListCard({
    required this.report,
    required this.dateLabel,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final SituationalIncidentReport report;
  final String dateLabel;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        (report.incidentType != null && report.incidentType!.isNotEmpty)
            ? report.incidentType!
            : 'Incident #${report.id ?? '—'}';

    final refer =
        report.referToHospital?.toLowerCase() == 'yes'
            ? 'Hospital referral'
            : null;

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
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
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(17),
                      bottomLeft: Radius.circular(17),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 15,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          dateLabel,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: AppColors.textMuted,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Actions',
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: AppColors.textMuted,
                              ),
                              onSelected: (value) {
                                switch (value) {
                                  case 'view':
                                    onOpen();
                                  case 'edit':
                                    onEdit();
                                  case 'delete':
                                    onDelete();
                                }
                              },
                              itemBuilder:
                                  (ctx) => [
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: ListTile(
                                        leading: Icon(Icons.visibility_rounded),
                                        title: Text('View details'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: ListTile(
                                        leading: Icon(Icons.edit_rounded),
                                        title: Text('Edit'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.delete_outline_rounded,
                                          color: AppColors.accent,
                                        ),
                                        title: Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                            ),
                          ],
                        ),
                        if (report.location != null &&
                            report.location!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  report.location!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.85,
                                    ),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (report.avpuSelectionKey != null)
                              _MiniChip(
                                label: 'AVPU recorded',
                                emphasized: true,
                              ),
                            if (refer != null)
                              _MiniChip(label: refer, emphasized: false),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'View record',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ],
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

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.emphasized});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:
            emphasized
                ? AppColors.primarySoft
                : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              emphasized
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: emphasized ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}
