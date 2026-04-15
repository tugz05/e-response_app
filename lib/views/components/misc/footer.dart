import 'package:flutter/material.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              'Developed by North Eastern Mindanao State University',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          const SizedBox(width: 6),
          Image.asset('lib/assets/images/nemsu.png', height: 18, width: 18),
        ],
      ),
    );
  }
}
