import 'package:e_response_app_nemsu/services/forgotpassword_service.dart';
import 'package:flutter/material.dart';



class ForgotPasswordController {
  final TextEditingController emailOrPhoneController = TextEditingController();
  final ForgotPasswordService _forgotPasswordService = ForgotPasswordService();

  Future<void> sendVerificationCode(BuildContext context) async {
    final emailOrPhone = emailOrPhoneController.text;

    if (emailOrPhone.isEmpty) {
      _showDialog(context, "Error", "Please enter your email or phone number.");
      return;
    }

    final result = await _forgotPasswordService.sendVerificationCode(emailOrPhone);

    if (result['success']) {
      _showDialog(context, "Success", result['message']);
      // Navigate to the next page or perform other actions as needed
    } else {
      _showDialog(context, "Error", result['message']);
    }
  }

  void _showDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }
}
