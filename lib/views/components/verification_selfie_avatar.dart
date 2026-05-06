import 'dart:io';

import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Avatar from the verification selfie path in SharedPreferences ([img_selfie]).
/// Falls back to initials when missing, on web, or if the file is gone.
class VerificationSelfieAvatar extends StatelessWidget {
  const VerificationSelfieAvatar({
    super.key,
    required this.displayName,
    this.selfiePath,
    this.radius = 28,
  });

  final String displayName;
  final String? selfiePath;
  final double radius;

  static String initialsFor(String fullName) {
    final parts =
        fullName
            .trim()
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .toList();
    if (parts.isEmpty) {
      return 'U';
    }
    if (parts.length == 1) {
      final s = parts.single;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = radius * 2;
    final initials = initialsFor(displayName);

    final path = selfiePath?.trim();
    if (!kIsWeb &&
        path != null &&
        path.isNotEmpty &&
        File(path).existsSync()) {
      return ClipOval(
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(theme, initials),
        ),
      );
    }

    return _fallback(theme, initials);
  }

  Widget _fallback(ThemeData theme, String initials) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      child: Text(
        initials,
        style: theme.textTheme.titleMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
