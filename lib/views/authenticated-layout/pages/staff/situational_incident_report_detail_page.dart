import 'package:e_response_app_nemsu/models/situational_incident_report.dart';
import 'package:e_response_app_nemsu/services/shared_preferences/SharedPreferencesService.dart';
import 'package:e_response_app_nemsu/services/situational_incident_report_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/staff/situational_incident_report_delete_dialog.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/staff/situational_incident_report_form_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Read-only situational incident report with edit / delete actions.
class SituationalIncidentReportDetailPage extends StatefulWidget {
  const SituationalIncidentReportDetailPage({super.key, required this.reportId});

  final int reportId;

  @override
  State<SituationalIncidentReportDetailPage> createState() =>
      _SituationalIncidentReportDetailPageState();
}

class _SituationalIncidentReportDetailPageState
    extends State<SituationalIncidentReportDetailPage> {
  final _service = SituationalIncidentReportService();
  final _prefs = SharedPreferencesService();

  SituationalIncidentReport? _report;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final creds = await _prefs.getCredentials();
    final token = creds['token'] ?? '';
    if (!mounted) {
      return;
    }
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Session expired. Sign in again.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _service.fetchOne(widget.reportId, bearerToken: token);

    if (!mounted) {
      return;
    }

    if (!result.isSuccess || result.data == null) {
      final msg = result.failureSnackText('Could not load report');
      setState(() {
        _loading = false;
        _error = msg;
        _report = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _loading = false;
      _report = result.data;
    });
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) {
      return '—';
    }
    final local = dt.toLocal();
    return '${DateFormat('MMM d, y').format(local)} · ${DateFormat.jm().format(local)}';
  }

  String _formatHm12(String? raw) {
    final parsed = SituationalIncidentReport.parseTimeHm(raw);
    if (parsed == null) {
      return raw?.trim().isNotEmpty == true ? raw!.trim() : '—';
    }
    final dt = DateTime(1970, 1, 1, parsed.hour, parsed.minute);
    return DateFormat.jm().format(dt);
  }

  Future<void> _openEdit() async {
    final nav =
        Navigator.maybeOf(context, rootNavigator: true) ??
        Navigator.maybeOf(context);
    if (nav == null) {
      return;
    }
    final changed = await nav.push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) =>
                SituationalIncidentReportFormPage(existingId: widget.reportId),
      ),
    );
    if (!mounted) {
      return;
    }
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _confirmDelete() async {
    final creds = await _prefs.getCredentials();
    final token = creds['token'] ?? '';
    if (!mounted || token.isEmpty) {
      return;
    }

    final ok = await confirmDeleteSituationalIncidentReport(
      context,
      recordTitle:
          _report?.incidentType ?? 'Incident #${widget.reportId}',
      recordId: widget.reportId,
    );

    if (!ok || !mounted) {
      return;
    }

    setState(() => _busy = true);
    final result = await _service.delete(widget.reportId, bearerToken: token);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

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
    Navigator.of(context, rootNavigator: true).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F8),
      appBar: AppBar(
        title: const Text('Incident record'),
        actions: [
          if (!_loading && _error == null && _report != null) ...[
            IconButton(
              tooltip: 'Edit',
              onPressed: _busy ? null : _openEdit,
              icon: const Icon(Icons.edit_rounded),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: _busy ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _report == null
              ? _ErrorState(message: 'No data', onRetry: _load)
              : Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        _HeroSummaryCard(report: _report!, theme: theme),
                        const SizedBox(height: 14),
                        _DetailSectionCard(
                          icon: Icons.person_search_rounded,
                          title: 'Intake & timeline',
                          child: Column(
                            children: [
                              _DetailRow(
                                label: 'Caller',
                                value: _report!.callerSourceOfInformation,
                              ),
                              _DetailRow(
                                label: 'Receiver',
                                value: _report!.receiver,
                              ),
                              _DetailRow(
                                label: 'Date & time received',
                                value: _formatDateTime(_report!.dateTimeReceived),
                              ),
                              _DetailRow(
                                label: 'Time of response',
                                value: _formatHm12(_report!.timeOfResponse),
                              ),
                              _DetailRow(
                                label: 'Location',
                                value: _report!.location,
                              ),
                              _DetailRow(
                                label: 'Landmark',
                                value: _report!.landmark,
                              ),
                            ],
                          ),
                        ),
                        _DetailSectionCard(
                          icon: Icons.article_outlined,
                          title: 'Incident narrative',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _DetailRow(
                                label: 'Details',
                                value: _report!.detailsOfIncident,
                                multiline: true,
                              ),
                              _DetailRow(
                                label: 'Vehicles involved',
                                value: _report!.vehiclesInvolved,
                                multiline: true,
                              ),
                            ],
                          ),
                        ),
                        _DetailSectionCard(
                          icon: Icons.monitor_heart_outlined,
                          title: 'Clinical assessment',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AVPU',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _avpuChips(_report!),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'DCAPTELS',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _injuryChips(_report!),
                              ),
                              if (_report!.examinationNotes != null &&
                                  _report!.examinationNotes!.trim().isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _DetailRow(
                                  label: 'Examination notes',
                                  value: _report!.examinationNotes,
                                  multiline: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                        _DetailSectionCard(
                          icon: Icons.medical_services_outlined,
                          title: 'Disposition',
                          child: Column(
                            children: [
                              _DetailRow(
                                label: 'Action taken',
                                value: _report!.actionTaken,
                                multiline: true,
                              ),
                              _DetailRow(
                                label: 'Refer to hospital',
                                value: _referLabel(_report!.referToHospital),
                              ),
                              _DetailRow(
                                label: 'Time transported',
                                value: _formatHm12(_report!.timeTransported),
                              ),
                              _DetailRow(
                                label: 'Hospital',
                                value: _report!.nameOfHospital,
                              ),
                            ],
                          ),
                        ),
                        _DetailSectionCard(
                          icon: Icons.groups_outlined,
                          title: 'Resources',
                          child: Column(
                            children: [
                              _DetailRow(
                                label: 'Responders',
                                value: _report!.nameOfResponders,
                                multiline: true,
                              ),
                              _DetailRow(
                                label: 'Response vehicle',
                                value: _report!.nameOfResponseVehicle,
                              ),
                            ],
                          ),
                        ),
                        if (_report!.createdAt != null ||
                            _report!.updatedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              [
                                if (_report!.createdAt != null)
                                  'Created ${_report!.createdAt}',
                                if (_report!.updatedAt != null)
                                  'Updated ${_report!.updatedAt}',
                              ].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _busy ? null : _openEdit,
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Edit report'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _confirmDelete,
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.accent,
                          ),
                          label: Text(
                            'Delete report',
                            style: TextStyle(color: AppColors.accent),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_busy)
                    Positioned.fill(
                      child: AbsorbPointer(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.22),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
    );
  }

  static String? _referLabel(String? raw) {
    final s = raw?.trim().toLowerCase();
    if (s == null || s.isEmpty) {
      return null;
    }
    if (s == 'yes') {
      return 'Yes';
    }
    if (s == 'no') {
      return 'No';
    }
    return raw;
  }

  static List<Widget> _avpuChips(SituationalIncidentReport r) {
    const labels = <String, String>{
      'alert': 'A — Alert',
      'verbal': 'V — Verbal',
      'pain': 'P — Pain',
      'unconscious': 'U — Unconscious',
    };
    final key = r.avpuSelectionKey;
    if (key == null) {
      return [
        Text(
          'Not recorded',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ];
    }
    return [
      Chip(
        label: Text(labels[key] ?? key),
        backgroundColor: AppColors.primarySoft,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          fontSize: 13,
        ),
      ),
    ];
  }

  static List<Widget> _injuryChips(SituationalIncidentReport r) {
    final flags = [
      (r.hasDeformity, 'D', 'Deformity'),
      (r.hasContusion, 'C', 'Contusion'),
      (r.hasAbrasion, 'A', 'Abrasion'),
      (r.hasPuncturePenetration, 'P', 'Puncture'),
      (r.hasTenderness, 'T', 'Tenderness'),
      (r.hasLaceration, 'L', 'Laceration'),
      (r.hasSwelling, 'S', 'Swelling'),
    ];
    final active = flags.where((e) => e.$1).toList();
    if (active.isEmpty) {
      return [
        Text(
          'None indicated',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ];
    }
    return [
      for (final e in active)
        Chip(
          label: Text('${e.$2} — ${e.$3}'),
          visualDensity: VisualDensity.compact,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
    ];
  }
}

class _HeroSummaryCard extends StatelessWidget {
  const _HeroSummaryCard({required this.report, required this.theme});

  final SituationalIncidentReport report;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final title =
        (report.incidentType != null && report.incidentType!.isNotEmpty)
            ? report.incidentType!
            : 'Situational incident';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            Color.lerp(AppColors.primary, AppColors.primaryAlt, 0.45)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.dateTimeReceived != null
                        ? '${DateFormat('MMM d, y').format(report.dateTimeReceived!.toLocal())} · ${DateFormat.jm().format(report.dateTimeReceived!.toLocal())}'
                        : 'No receive timestamp',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (report.location != null && report.location!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.location!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailSectionCard extends StatelessWidget {
  const _DetailSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 22, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String? value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final v = value?.trim();
    if (v == null || v.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            v,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: multiline ? 1.45 : 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(Icons.cloud_off_outlined, size: 52, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
