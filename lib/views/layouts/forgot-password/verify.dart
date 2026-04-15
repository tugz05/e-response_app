import 'dart:async';
import 'package:e_response_app_nemsu/controllers/VTextFieldController.dart';
import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/views/components/VButton.dart';
import 'package:e_response_app_nemsu/views/components/VCaption.dart';
import 'package:e_response_app_nemsu/views/components/VTextField.dart';
import 'package:e_response_app_nemsu/views/components/VlLogo.dart';
import 'package:flutter/material.dart';
import 'package:e_response_app_nemsu/services/forgotpassword_service.dart';
import 'package:e_response_app_nemsu/services/verifyOTP_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';

class VerifyPage extends StatefulWidget {
  final String email;

  const VerifyPage({Key? key, required this.email}) : super(key: key);

  @override
  _VerifyPageState createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final VerifyOTPService _verifyOTPService = VerifyOTPService();
  final ForgotPasswordService _forgotPasswordService = ForgotPasswordService();
  final VTextFieldController _codeController = VTextFieldController();

  bool _isLoading = false;
  bool _canResend = true;
  Timer? _resendTimer;
  int _resendCooldown = 60;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() {
      _canResend = false;
      _resendCooldown = 60;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCooldown -= 1;
      });

      if (_resendCooldown <= 0) {
        timer.cancel();
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  void _resendCode() async {
    setState(() {
      _isLoading = true;
    });

    final response = await _forgotPasswordService.sendVerificationCode(widget.email);

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification code resent successfully')),
      );
      _startResendCooldown();
    } else {
      final message = response['message'] ?? 'Failed to resend code';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _verifyCode() async {
    final code = _codeController.text;

    setState(() {
      _isLoading = true;
    });

    final response = await _verifyOTPService.verifyCode(widget.email, code);

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      Navigator.pushNamed(context, RouteManager.newPasswordPage);
      final message = response['message'] ?? 'Verification failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else {
      final message = response['message'] ?? 'Verification failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            VLogo(),
            SizedBox(height: 30),
            VCaption(
              header: "Verify your account",
              text: "Please enter the code we’ve sent you to verify your account",
            ),
            SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  VTextField(
                    controller: _codeController,
                    hintText: "Enter Code",
                  ),
                  SizedBox(height: 30),
                  VButton(
                    isLoading: _isLoading,
                    onPressed: _isLoading ? () {} : _verifyCode,
                    text: "Verify Account",
                  ),
                  SizedBox(height: 40),
                  GestureDetector(
                    onTap: _canResend ? _resendCode : null,
                    child: Text(
                      _canResend ? "Resend Code" : "Resend in $_resendCooldown seconds",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _canResend
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
