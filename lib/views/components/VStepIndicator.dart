import 'package:flutter/material.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';

// Enum to represent the different states of the account creation process
enum AccountState { creating, verification, accountCreated }

class VStepIndicator extends StatelessWidget {
  final AccountState accountState; // Accepts the current state

  const VStepIndicator({super.key, required this.accountState});

  @override
  Widget build(BuildContext context) {
    // Determine whether step 1 and step 2 are checked based on the accountState
    bool isStep1Checked = accountState == AccountState.verification || accountState == AccountState.accountCreated;
    bool isStep2Checked = accountState == AccountState.accountCreated;

    return Container(
      color: AppColors.backgroundAlt,
      child: Padding(
        padding: const EdgeInsets.all(35.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Step 1
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(6), // Space between outer circle and avatar
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isStep1Checked
                          ? AppColors.primary
                          : AppColors.primary,
                      width: 1.0, // Thickness of the outer circle line
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: isStep1Checked
                        ? AppColors.primary
                        : AppColors.primary,
                    child: isStep1Checked
                        ? Icon(Icons.check, color: Colors.white) // Display check icon if checked
                        : Container(), // Empty if not checked
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'STEP 1',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.textMuted),
                ),
                const Text(
                  'Create Account',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(width: 20),
            // Line between steps
            Container(
              width: 25,
              height: 2,
              color: isStep1Checked
                  ? AppColors.primary
                  : AppColors.textMuted,
            ),
            Container(
              width: 25,
              height: 2,
              color: isStep2Checked
                  ? AppColors.primary
                  : AppColors.textMuted,
            ),
            SizedBox(width: 20),
            // Step 2
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(6), // Space between outer circle and avatar
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isStep2Checked
                          ? AppColors.primary
                          : AppColors.textMuted,
                      width: 1.0, // Thickness of the outer circle line
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: isStep2Checked
                        ? AppColors.primary
                        : AppColors.border,
                    child: isStep2Checked
                        ? Icon(Icons.check, color: Colors.white) // Display check icon if checked
                        : Container(), // Empty if not checked
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'STEP 2',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          isStep2Checked
                              ? AppColors.textPrimary
                              : AppColors.textMuted),
                ),
                Text('Verification',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            isStep2Checked
                                ? AppColors.textPrimary
                                : AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
