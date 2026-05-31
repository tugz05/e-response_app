import 'package:flutter/material.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';

/// A full‐screen prompt that explains why we need the Phone Account enabled.
/// When the user taps the button, we call TwilioService.promptEnablePhoneAccount().
class PhoneAccountPrompt extends StatelessWidget {
  const PhoneAccountPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    // Use a Scaffold so we can control back‐stack behavior if needed.
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Enable Calling Account'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1) A short explanatory illustration or icon
            const Icon(
              Icons.phone_android,
              size: 100,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),

            // 2) A headline
            const Text(
              'Enable “Phone Account” for VoIP Calling',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // 3) Explanatory text
            const Text(
              'To make and receive voice calls without a SIM card, '
              'we need you to enable our app as a “Phone Account” (default dialer). '
              'This allows us to integrate with your phone’s call UI.\n\n'
              'Tap the button below to open your device’s Phone Account settings, '
              'then select “E-Response App” as the default phone app. '
              'Once enabled, return here and you’ll be able to place VoIP calls.',
              style: TextStyle(fontSize: 16, color: AppColors.textMuted),
              textAlign: TextAlign.left,
            ),
            const Spacer(),

            // 4) “Take me there” button
            ElevatedButton.icon(
              onPressed: () {
                // 4a) Open the Phone Account settings
                // TwilioService().promptEnablePhoneAccount();

                // 4b) Optionally, pop this prompt so user can return to previous screen
                // Navigator.of(context).pop();
              },
              icon: const Icon(Icons.settings_phone),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14.0),
                child: Text(
                  'Take Me to Settings',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 5) A “Maybe Later” link
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // just go back
              },
              child: const Text(
                'Maybe Later',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textMuted,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
