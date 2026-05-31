import 'dart:convert';
import 'package:e_response_app_nemsu/controllers/VTextFieldController.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/components/VButton.dart';
import 'package:e_response_app_nemsu/views/components/VTextField.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final VTextFieldController _currentPasswordController = VTextFieldController();
  final VTextFieldController _newPasswordController = VTextFieldController();

  bool _isLoading = false;

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.accent,
      ),
    );
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    // Validation
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      _showMessage("Please fill in all fields.");
      return;
    }
    if (newPassword.length < 6) {
      _showMessage("New password must be at least 6 characters.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('id');
      if (userId == null) {
        _showMessage("User not found.");
        setState(() => _isLoading = false);
        return;
      }

      final uri = Uri.parse('https://cdrrmo-tandag.com/api/v1/password');
      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'id': userId,
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        _showMessage("Password changed successfully!", success: true);
        _currentPasswordController.text = '';
        _newPasswordController.text = '';
      } else {
        String msg = "Failed to change password";
        try {
          final data = json.decode(response.body);
          if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        } catch (_) {}
        _showMessage(msg);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Error: $e");
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  VTextField(
                    hintText: "Current Password",
                    controller: _currentPasswordController,
                    isPassword: true,
                  ),
                  SizedBox(height: 10),
                  VTextField(
                    hintText: "New Password",
                    controller: _newPasswordController,
                    isPassword: true,
                  ),
                  SizedBox(height: 30),
                  VButton(
                    onPressed: _isLoading ? () {} : _changePassword,
                    isLoading: _isLoading,
                    text: "Change Password",
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
