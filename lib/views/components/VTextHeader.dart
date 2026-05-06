import 'package:flutter/material.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';

class VTextHeader extends StatelessWidget {
  final String text;
  const VTextHeader({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
