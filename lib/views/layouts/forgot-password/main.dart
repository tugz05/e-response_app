import 'package:e_response_app_nemsu/controllers/VTextFieldController.dart';
import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/services/forgotpassword_service.dart';
import 'package:flutter/material.dart';
import 'package:e_response_app_nemsu/views/components/VButton.dart';
import 'package:e_response_app_nemsu/views/components/VCaption.dart';
import 'package:e_response_app_nemsu/views/components/VTextField.dart';
import 'package:e_response_app_nemsu/views/components/VlLogo.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final VTextFieldController _controller = VTextFieldController();
  final ForgotPasswordService _forgotPasswordService = ForgotPasswordService();
    bool _isLoading = false;

  @override
  void dispose() {
    // Dispose of the controller when the widget is removed from the widget tree
    _controller.dispose();
    super.dispose();
  }

void _sendOTP() async {
    final email = _controller.textController.text;

    setState(() {
      _isLoading = true;
    });

    final response = await _forgotPasswordService.sendVerificationCode(email);

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      print("Sent OTP");
      final message = response['message'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.pushNamed(
      context,
      RouteManager.enterCodePage,
      arguments: email, // Pass email as an argument
    );
    }
    else {
      final message = response['message'] ?? 'An unknown error occurred';
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
              header: 'Forgot Password',
              text:
                  'Please enter your registered email or phone number and we’ll send your verification code',
            ),
            SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
              child: Column(
                children: [
                  VTextField(
                    controller: _controller,
                    hintText: "Email/Phone",
                  ),
                  SizedBox(height: 30),
                  VButton(
                    isLoading: _isLoading, // Set loading state
                    onPressed: _isLoading ? () {} : _sendOTP,
                    text: "Send Verification Code",
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
