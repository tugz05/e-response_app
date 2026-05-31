import 'package:e_response_app_nemsu/models/citizen_report_detail.dart';
import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/services/citizen_report_service.dart';
import 'package:e_response_app_nemsu/services/shared_preferences/SharedPreferencesService.dart';
import 'package:e_response_app_nemsu/services/tracking_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/staff/situational_incident_report_form_args.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Loads `GET /api/v1/reports/{id}` and presents a full intake record.
class CitizenReportDetailPage extends StatefulWidget {
  const CitizenReportDetailPage({super.key, required this.reportId});

  final int reportId;

  @override
  State<CitizenReportDetailPage> createState() =>
      _CitizenReportDetailPageState();
}

class _CitizenReportDetailPageState extends State<CitizenReportDetailPage> {
  final _service = CitizenReportService();
  final _prefs = SharedPreferencesService();

  CitizenReportDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _startingRescue = false;

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
      setState(() {
        _loading = false;
        _error = result.errorMessage ?? 'Could not load report';
        _detail = null;
      });
      return;
    }

    setState(() {
      _loading = false;
      _detail = result.data;
    });
  }

  Future<void> _openMaps(CitizenReportDetail r) async {
    final lat = double.tryParse(r.latitude ?? '');
    final lng = double.tryParse(r.longitude ?? '');
    if (lat == null || lng == null) {
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// True when the report has coordinates and is not yet completed/resolved.
  bool get _canStartRescue {
    final d = _detail;
    if (d == null) return false;
    if (double.tryParse(d.latitude ?? '') == null) return false;
    if (double.tryParse(d.longitude ?? '') == null) return false;
    final s = d.status?.toLowerCase() ?? '';
    return !s.contains('complet') && !s.contains('resolv');
  }

  Future<void> _startRescue() async {
    final d = _detail;
    if (d == null || !_canStartRescue) return;

    final lat = double.parse(d.latitude!);
    final lng = double.parse(d.longitude!);

    setState(() => _startingRescue = true);

    try {
      final creds = await _prefs.getCredentials();
      final rescuerIdStr = creds['id'] ?? '';
      final rescuerId = int.tryParse(rescuerIdStr);
      if (rescuerId == null || !mounted) return;

      await TrackingService.startSession(
        reportId: d.id,
        residentUserId: d.userId ?? 0,
        rescuerUserId: rescuerId,
        residentLat: lat,
        residentLng: lng,
      );

      if (!mounted) return;

      final residentName = (d.reportedBy?.trim().isNotEmpty == true)
          ? d.reportedBy!.trim()
          : (d.user?.name?.trim().isNotEmpty == true
              ? d.user!.name!.trim()
              : 'Resident');

      await Navigator.of(context).pushNamed(
        RouteManager.rescueTracking,
        arguments: TrackingArgs(
          reportId: d.id,
          role: TrackingRole.rescuer,
          residentLat: lat,
          residentLng: lng,
          residentName: residentName,
          residentUserId: d.userId,
          rescuerUserId: rescuerId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start rescue: $e')),
      );
    } finally {
      if (mounted) setState(() => _startingRescue = false);
    }
  }

  Future<void> _draftSituational() async {
    final d = _detail;
    if (d == null) {
      return;
    }
    await Navigator.of(context, rootNavigator: true).pushNamed(
      RouteManager.situationalIncidentReportForm,
      arguments: SituationalIncidentReportFormArgs(
        citizenReportPrefill: d.toCitizenFormPrefill(),
      ),
    );
  }

  String _dt(DateTime? dt) {
    if (dt == null) {
      return '—';
    }
    final local = dt.toLocal();
    return '${DateFormat('MMM d, y').format(local)} · ${DateFormat.jm().format(local)}';
  }

  static String _manualLabel(String? raw) {
    final s = raw?.trim().toLowerCase();
    if (s == '1' || s == 'true' || s == 'yes') {
      return 'Yes';
    }
    return 'No';
  }

  void _showImageLightbox(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(url, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F7),
      appBar: AppBar(
        title: const Text('Citizen report'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorPane(message: _error!, onRetry: _load)
              : _detail == null
              ? _ErrorPane(message: 'No data', onRetry: _load)
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                  children: [
                    _HeroCard(detail: _detail!, theme: theme),
                    const SizedBox(height: 14),
                    _SectionCard(
                      icon: Icons.flag_outlined,
                      title: 'Case status',
                      child: _StatusBanner(status: _detail!.status ?? '—'),
                    ),
                    if (_detail!.details != null &&
                        _detail!.details!.trim().isNotEmpty)
                      _SectionCard(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Reported details',
                        child: SelectableText(
                          _detail!.details!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ),
                    _LocationSection(
                      detail: _detail!,
                      onOpenMaps: () => _openMaps(_detail!),
                    ),
                    if (_detail!.reportedBy != null ||
                        _detail!.reportersAddress != null)
                      _SectionCard(
                        icon: Icons.person_pin_circle_outlined,
                        title: 'Reporter',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_detail!.reportedBy != null &&
                                _detail!.reportedBy!.isNotEmpty)
                              _LabeledValue(
                                label: 'Reported by',
                                value: _detail!.reportedBy!,
                              ),
                            if (_detail!.reportersAddress != null &&
                                _detail!.reportersAddress!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _LabeledValue(
                                label: 'Reporter address',
                                value: _detail!.reportersAddress!,
                              ),
                            ],
                          ],
                        ),
                      ),
                    _SectionCard(
                      icon: Icons.schedule_outlined,
                      title: 'Timeline',
                      child: Column(
                        children: [
                          _LabeledValue(
                            label: 'Submitted',
                            value: _dt(_detail!.createdAt),
                          ),
                          if (_detail!.callStartedAt != null) ...[
                            const SizedBox(height: 12),
                            _LabeledValue(
                              label: 'Call / session started',
                              value: _dt(_detail!.callStartedAt),
                            ),
                          ],
                          if (_detail!.callEndedAt != null) ...[
                            const SizedBox(height: 12),
                            _LabeledValue(
                              label: 'Call / session ended',
                              value: _dt(_detail!.callEndedAt),
                            ),
                          ],
                          if (_detail!.updatedAt != null) ...[
                            const SizedBox(height: 12),
                            _LabeledValue(
                              label: 'Last updated',
                              value: _dt(_detail!.updatedAt),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _SectionCard(
                      icon: Icons.tune_rounded,
                      title: 'Capture metadata',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LabeledValue(
                            label: 'GPS accuracy (m)',
                            value: _detail!.accuracy ?? '—',
                          ),
                          const SizedBox(height: 12),
                          _LabeledValue(
                            label: 'Manually entered',
                            value: _manualLabel(_detail!.isManuallyAdded),
                          ),
                        ],
                      ),
                    ),
                    if (_detail!.user != null &&
                        (_detail!.user!.name != null ||
                            _detail!.user!.phone != null ||
                            _detail!.user!.email != null))
                      _SectionCard(
                        icon: Icons.account_circle_outlined,
                        title: 'Registered account',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_detail!.user!.name != null)
                              _LabeledValue(
                                label: 'Name',
                                value: _detail!.user!.name!,
                              ),
                            if (_detail!.user!.phone != null &&
                                _detail!.user!.phone!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _RowIcon(
                                icon: Icons.phone_outlined,
                                text: _detail!.user!.phone!,
                              ),
                            ],
                            if (_detail!.user!.email != null &&
                                _detail!.user!.email!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _RowIcon(
                                icon: Icons.email_outlined,
                                text: _detail!.user!.email!,
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (_detail!.reportImages.isNotEmpty)
                      _AttachmentsStrip(
                        images: _detail!.reportImages,
                        onTapImage: (url) => _showImageLightbox(context, url),
                      ),
                  ],
                ),
              ),
      bottomNavigationBar:
          _detail == null
              ? null
              : Material(
                elevation: 16,
                color: Colors.white,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_canStartRescue) ...[
                          FilledButton.icon(
                            onPressed: _startingRescue ? null : _startRescue,
                            icon: _startingRescue
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.navigation_rounded),
                            label: const Text('Start Rescue Navigation'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              backgroundColor: AppColors.success,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        FilledButton.icon(
                          onPressed: _draftSituational,
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text('Draft situational report'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.detail, required this.theme});

  final CitizenReportDetail detail;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final accent = detail.isMessage ? AppColors.secondary : AppColors.accent;
    final headline =
        (detail.reportedBy != null && detail.reportedBy!.trim().isNotEmpty)
            ? detail.reportedBy!.trim()
            : (detail.user?.name?.trim().isNotEmpty == true
                  ? detail.user!.name!.trim()
                  : 'Citizen report');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent,
            Color.lerp(accent, AppColors.primary, 0.28)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.38),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                detail.isMessage ? 'MESSAGE' : 'CALL',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              headline,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    detail.createdAt != null
                        ? '${DateFormat('MMM d, y').format(detail.createdAt!.toLocal())} · ${DateFormat.jm().format(detail.createdAt!.toLocal())}'
                        : '—',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.93),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.detail,
    required this.onOpenMaps,
  });

  final CitizenReportDetail detail;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCoords =
        (detail.latitude != null && detail.latitude!.isNotEmpty) &&
        (detail.longitude != null && detail.longitude!.isNotEmpty);

    return _SectionCard(
      icon: Icons.map_outlined,
      title: 'Location',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.address != null && detail.address!.isNotEmpty)
            SelectableText(
              detail.address!,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
          if (hasCoords) ...[
            if (detail.address != null && detail.address!.isNotEmpty)
              const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                '${detail.latitude}, ${detail.longitude}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenMaps,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open in maps'),
            ),
          ],
          if ((detail.address == null || detail.address!.isEmpty) && !hasCoords)
            Text(
              'No address or coordinates on file.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachmentsStrip extends StatelessWidget {
  const _AttachmentsStrip({
    required this.images,
    required this.onTapImage,
  });

  final List<CitizenReportImage> images;
  final void Function(String url) onTapImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                  const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Attachments · ${images.length}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final url = images[i].fullUrl;
                    return Material(
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onTapImage(url),
                        child: SizedBox(
                          width: 112,
                          height: 112,
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => ColoredBox(
                              color: const Color(0xFFF1F5F9),
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.textMuted,
                              ),
                            ),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) {
                                return child;
                              }
                              return const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to zoom. Images load from server storage.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft.withValues(alpha: 0.32),
              blurRadius: 14,
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
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg = AppColors.primarySoft;
    Color fg = AppColors.primary;
    if (s.contains('pending')) {
      bg = AppColors.warning.withValues(alpha: 0.14);
      fg = AppColors.warning;
    } else if (s.contains('complete') || s.contains('resolved')) {
      bg = AppColors.success.withValues(alpha: 0.12);
      fg = AppColors.success;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          fontSize: 13,
          color: fg,
        ),
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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
        SelectableText(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
        ),
      ],
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: SelectableText(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
