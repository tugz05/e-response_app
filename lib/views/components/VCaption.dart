import 'package:flutter/material.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';

class VCaption extends StatelessWidget {
  final String header;
  final String  text;

    const VCaption({
    Key? key,
    required this.header,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          header,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
              ),
            )
      ]
    );
  }
}
