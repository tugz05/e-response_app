import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Confirms permanent deletion of a situational incident report (CDRRMO record).
Future<bool> confirmDeleteSituationalIncidentReport(
  BuildContext context, {
  required String recordTitle,
  required int recordId,
}) async {
  final theme = Theme.of(context);
  final title =
      recordTitle.trim().isEmpty ? 'Untitled incident record' : recordTitle.trim();

  final agreed =
      await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            icon: CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.accent.withValues(alpha: 0.12),
              child: Icon(
                Icons.delete_forever_rounded,
                color: AppColors.accent,
                size: 28,
              ),
            ),
            title: Text(
              'Delete situational incident record?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will permanently remove the structured CDRRMO incident '
                    'report from the active database. The action applies to all '
                    'users with access to this listing.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RECORD SUMMARY',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Reference ID #$recordId',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This cannot be undone. Archival or audit logs may '
                          'still retain metadata according to your organization’s policy.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete permanently'),
              ),
            ],
          );
        },
      ) ??
      false;

  return agreed;
}
