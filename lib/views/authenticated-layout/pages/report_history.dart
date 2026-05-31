import 'dart:io';

import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/services/report_history_service.dart';
import 'package:e_response_app_nemsu/services/tracking_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransactionHistory extends StatefulWidget {
  const TransactionHistory({super.key});

  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory> {
  final ReportHistoryService _service = ReportHistoryService();

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;
  bool _isOffline = false;

  /// Logged-in citizen's numeric user ID (stored as string from prefs).
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _isOffline = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('id') ?? '';
      final token = prefs.getString('token');

      if (uid.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'You must be signed in to view your report history.';
          _isLoading = false;
        });
        return;
      }

      _userId = uid;

      final result = await _service.fetchForUser(uid, bearerToken: token);

      if (!mounted) return;

      if (!result.isSuccess) {
        setState(() {
          _error = result.errorMessage ??
              'Could not load your report history. Please try again.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _items = (result.items ?? []).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _isOffline = true;
        _error =
            'No internet connection. Check your network and try again.';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy · h:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return AppColors.secondary;
      case 'en_route':
        return AppColors.primaryAlt;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  /// Returns true when this report should show a "Track Rescuer" button.
  bool _canTrack(Map<String, dynamic> tx) {
    final status = tx['status']?.toString().toLowerCase() ?? '';
    if (status != 'en_route' && status != 'confirmed') return false;
    final lat = double.tryParse(tx['latitude']?.toString() ?? '');
    final lng = double.tryParse(tx['longitude']?.toString() ?? '');
    return lat != null && lng != null;
  }

  void _openTracking(BuildContext ctx, Map<String, dynamic> tx) {
    final rawId = tx['id'] ?? tx['report_id'];
    final reportId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;
    final lat = double.tryParse(tx['latitude']?.toString() ?? '') ?? 0;
    final lng = double.tryParse(tx['longitude']?.toString() ?? '') ?? 0;
    final residentUserId = int.tryParse(_userId) ?? 0;

    Navigator.of(ctx).pushNamed(
      RouteManager.rescueTracking,
      arguments: TrackingArgs(
        reportId: reportId,
        role: TrackingRole.citizen,
        residentLat: lat,
        residentLng: lng,
        residentUserId: residentUserId,
      ),
    );
  }

  IconData _typeIcon(String type) {
    return type.toLowerCase() == 'message'
        ? Icons.message_outlined
        : Icons.call_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Report History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _fetch,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: _buildBody(theme),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // Loading skeleton
    if (_isLoading) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => _SkeletonTile(),
      );
    }

    // Error state
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
        children: [
          _ErrorCard(
            isOffline: _isOffline,
            message: _error!,
            onRetry: _fetch,
          ),
        ],
      );
    }

    // Empty state
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    size: 34,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No reports yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reports you submit (message or voice call) will\nappear here with their status.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // List
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final tx = _items[i];
        final type = tx['type']?.toString() ?? 'Report';
        final status = tx['status']?.toString() ?? 'N/A';
        final details = tx['details']?.toString() ?? '';
        final address = tx['address']?.toString() ?? '';
        final createdAt = tx['created_at']?.toString() ?? '';
        final secondary = details.isNotEmpty ? details : address;

        return _ReportHistoryCard(
          icon: _typeIcon(type),
          type: type,
          status: status,
          statusColor: _statusColor(status),
          secondary: secondary,
          dateLabel: _formatDate(createdAt),
          onTrack: _canTrack(tx)
              ? () => _openTracking(context, tx)
              : null,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _ReportHistoryCard extends StatelessWidget {
  const _ReportHistoryCard({
    required this.icon,
    required this.type,
    required this.status,
    required this.statusColor,
    required this.secondary,
    required this.dateLabel,
    this.onTrack,
  });

  final IconData icon;
  final String type;
  final String status;
  final Color statusColor;
  final String secondary;
  final String dateLabel;

  /// When non-null, a "Track Rescuer" button is shown at the bottom of the card.
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              type,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (secondary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          secondary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.schedule_outlined,
                              size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            dateLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // ── Track Rescuer button ──────────────────────────────────────
            if (onTrack != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onTrack,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryAlt.withValues(alpha: 0.10),
                    foregroundColor: AppColors.primaryAlt,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.navigation_rounded, size: 17),
                  label: const Text(
                    'Track Rescuer',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
    required this.isOffline,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon =
        isOffline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded;
    final title = isOffline ? 'No internet connection' : 'Unable to load';
    final color = isOffline ? AppColors.warning : AppColors.accent;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                minimumSize: const Size(140, 42),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer-style skeleton tile while loading.
class _SkeletonTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.skeletonBase,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 13,
                    width: 140,
                    decoration: BoxDecoration(
                      color: AppColors.skeletonBase,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 11,
                    decoration: BoxDecoration(
                      color: AppColors.skeletonBase,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 90,
                    decoration: BoxDecoration(
                      color: AppColors.skeletonBase,
                      borderRadius: BorderRadius.circular(6),
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
