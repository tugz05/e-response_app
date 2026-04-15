import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

String contentPlainText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '';
  }

  return value
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String contentDateLabel(String? rawDate) {
  if (rawDate == null || rawDate.isEmpty) {
    return '';
  }

  try {
    return DateFormat('MMM d, yyyy').format(DateTime.parse(rawDate));
  } catch (_) {
    return rawDate;
  }
}

class ContentSectionHeader extends StatelessWidget {
  const ContentSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class ContentHeroCard extends StatelessWidget {
  const ContentHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.highlights,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String badge;
  final List<String> highlights;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowPrimary,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.84),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  highlights
                      .map(
                        (item) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            item,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class ContentFeedCard extends StatelessWidget {
  const ContentFeedCard({
    super.key,
    required this.title,
    required this.excerpt,
    required this.dateLabel,
    required this.onTap,
    this.imageUrl,
    this.icon = Icons.article_outlined,
    this.accentColor = AppColors.primary,
    this.compact = false,
  });

  final String title;
  final String excerpt;
  final String dateLabel;
  final VoidCallback onTap;
  final String? imageUrl;
  final IconData icon;
  final Color accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              compact
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ContentFeedCardVisual(
                        imageUrl: imageUrl,
                        icon: icon,
                        accentColor: accentColor,
                        height: 108,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                excerpt,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _FeedMeta(dateLabel: dateLabel),
                          ],
                        ),
                      ),
                    ],
                  )
                  : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ContentFeedCardVisual(
                        imageUrl: imageUrl,
                        icon: icon,
                        accentColor: accentColor,
                        height: 110,
                        width: 104,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              excerpt,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _FeedMeta(dateLabel: dateLabel),
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

class _ContentFeedCardVisual extends StatelessWidget {
  const _ContentFeedCardVisual({
    required this.imageUrl,
    required this.icon,
    required this.accentColor,
    required this.height,
    this.width = double.infinity,
  });

  final String? imageUrl;
  final IconData icon;
  final Color accentColor;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final String? validImage =
        imageUrl != null && imageUrl!.trim().isNotEmpty ? imageUrl : null;

    if (validImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          validImage,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) => _FallbackVisual(
                icon: icon,
                accentColor: accentColor,
                height: height,
                width: width,
              ),
        ),
      );
    }

    return _FallbackVisual(
      icon: icon,
      accentColor: accentColor,
      height: height,
      width: width,
    );
  }
}

class _FallbackVisual extends StatelessWidget {
  const _FallbackVisual({
    required this.icon,
    required this.accentColor,
    required this.height,
    required this.width,
  });

  final IconData icon;
  final Color accentColor;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.16),
            accentColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(icon, color: accentColor, size: 30),
    );
  }
}

class _FeedMeta extends StatelessWidget {
  const _FeedMeta({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.schedule_outlined,
          size: 14,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            dateLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class ContentEmptyState extends StatelessWidget {
  const ContentEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(18),
                ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContentLoadingList extends StatelessWidget {
  const ContentLoadingList({
    super.key,
    this.compact = false,
    this.itemCount = 3,
  });

  final bool compact;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
            padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 12),
            child: Shimmer.fromColors(
            baseColor: AppColors.skeletonBase,
            highlightColor: AppColors.skeletonHighlight,
              child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child:
                    compact
                        ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 108,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 16,
                              width: double.infinity,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 14,
                              width: 160,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 12,
                              width: 90,
                              color: Colors.white,
                            ),
                          ],
                        )
                        : Row(
                          children: [
                            Container(
                              width: 104,
                              height: 110,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(height: 16, color: Colors.white),
                                  const SizedBox(height: 8),
                                  Container(height: 14, color: Colors.white),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 14,
                                    width: 150,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 12,
                                    width: 90,
                                    color: Colors.white,
                                  ),
                                ],
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
