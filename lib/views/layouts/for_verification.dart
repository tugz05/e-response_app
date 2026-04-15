import 'package:flutter/material.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';

class VerifyAccountScreen extends StatelessWidget {
  const VerifyAccountScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // For the lock icon background color
    final Color iconBg = AppColors.backgroundAlt;

    return Scaffold(
      backgroundColor: AppColors.backgroundAlt,
      body: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          constraints: BoxConstraints(maxWidth: 400),
          child: Material(
            borderRadius: BorderRadius.circular(32),
            color: AppColors.surface,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Close Button
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  SizedBox(height: 8),
                  // Lock Icon with Circle
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: iconBg,
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  SizedBox(height: 24),
                  // Title
                  Text(
                    "We're verifying your account",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  // Description
                  Text(
                    "To proceed with this transaction, please complete identity verification. This helps us ensure the security of your account.",
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 36),
                  // Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Add your navigation logic here
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      child: Text(
                        "Go back to Login",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
