import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogoutModule extends StatelessWidget {
  const LogoutModule({Key? key}) : super(key: key);

  // Shows the custom confirmation dialog and logs out if confirmed
  static Future<void> confirmAndLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Duck image with question mark
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Image.asset(
                    'assets/logout_icon.jpg', // Your asset image
                    width: 90,
                    height: 90,
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'Logout?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
              SizedBox(height: 8),
              Text(
                'Are you sure you want to logout',
                style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: const BorderSide(color: AppColors.accent, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text("Yes, Logout", style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text("Nooo, Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldLogout == true) {
      await performLogout(context);
    }
  }

  // Actual logout logic (remains the same)
  static Future<void> performLogout(BuildContext context) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.of(context)
        .pushNamedAndRemoveUntil(RouteManager.loginPage, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListTile(
          leading: const Icon(Icons.logout, color: AppColors.primary),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
            ),
          ),
          onTap: () async {
            await confirmAndLogout(context);
          },
        ),
      ),
    );
  }
}
