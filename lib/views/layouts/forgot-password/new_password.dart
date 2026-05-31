import 'package:e_response_app_nemsu/views/components/VButton.dart';
import 'package:e_response_app_nemsu/views/components/VCaption.dart';
import 'package:e_response_app_nemsu/views/components/VTextField.dart';
import 'package:e_response_app_nemsu/views/components/VlLogo.dart';
import 'package:flutter/material.dart';

class NewPasswordPage extends StatelessWidget {
  const NewPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
            child: Column(
              children: [
                VLogo(),
                const SizedBox(height: 40),
                VCaption(
                  header: "New Password",
                  text: "Please enter your new password",
                ),
                const SizedBox(height: 40),
                VTextField(
                  hintText: "Enter New Password",
                  headerText: "New Password",
                ),
                VTextField(
                  hintText: "Re-enter New Password",
                  headerText: "Re-enter Password",
                ),
                const SizedBox(height: 40),
                VButton(
                  onPressed: () {},
                  text: "Change Password",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
