import 'package:e_response_app_nemsu/controllers/VTextFieldController.dart';
import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/services/signup_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/components/VButton.dart';
import 'package:e_response_app_nemsu/views/components/VDropDown.dart';
import 'package:e_response_app_nemsu/views/components/VStepIndicator.dart';
import 'package:e_response_app_nemsu/views/components/VTextField.dart';
import 'package:e_response_app_nemsu/views/components/VTextHeader.dart';
import 'package:e_response_app_nemsu/views/components/address_suggestion_field.dart';
import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isAgreed = false;

  final VTextFieldController _firstNameController = VTextFieldController();
  final VTextFieldController _lastNameController = VTextFieldController();
  final VTextFieldController _middleNameController = VTextFieldController();
  final VTextFieldController _addressController = VTextFieldController();
  final VTextFieldController _emailController = VTextFieldController();
  final VTextFieldController _phoneController = VTextFieldController();
  final VTextFieldController _passwordController = VTextFieldController();
  final VTextFieldController _confirmPasswordController =
      VTextFieldController();

  String? _selectedSuffix;
  bool _isLoading = false;

  final List<String> _suffixOptions = ['N/A', 'Jr', 'Sr', 'II', 'III', 'IV'];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateFields() {
    if (_firstNameController.text.trim().length < 2 ||
        _firstNameController.text.trim().length > 200) {
      return 'First name must be between 2 and 200 characters.';
    }
    if (_lastNameController.text.trim().length < 2 ||
        _lastNameController.text.trim().length > 200) {
      return 'Last name must be between 2 and 200 characters.';
    }
    if (_middleNameController.text.trim().isNotEmpty &&
        (_middleNameController.text.trim().length < 2 ||
            _middleNameController.text.trim().length > 200)) {
      return 'Middle name must be between 2 and 200 characters if provided.';
    }
    if (_emailController.text.trim().isEmpty ||
        !_emailController.text.contains('@')) {
      return 'Please provide a valid email address.';
    }
    if (_phoneController.text.trim().length != 11) {
      return 'Phone number must be 11 digits.';
    }
    if (_passwordController.text.length < 6 ||
        _passwordController.text.length > 255) {
      return 'Password must be between 6 and 255 characters.';
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      return 'Passwords do not match.';
    }
    final addr = _addressController.text.trim();
    if (addr.length < 5) {
      return 'Please enter a complete address (at least 5 characters).';
    }
    if (!_isAgreed) {
      return 'You must agree to the terms and conditions.';
    }

    return null;
  }

  Future<void> _register() async {
    final validationError = _validateFields();
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await SignupService.register(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      suffix: _selectedSuffix == 'N/A' ? null : _selectedSuffix,
      address: _addressController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      confirm_password: _confirmPasswordController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.pushNamed(context, RouteManager.verificationPage);
      return;
    }

    _showMessage('Registration failed. Please try again.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF4F7FB), Color(0xFFE7EEFA)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              26 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    const VStepIndicator(accountState: AccountState.creating),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create your account',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Complete your profile information to access emergency response services.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const VTextHeader(text: 'Personal Information'),
                            VTextField(
                              controller: _firstNameController,
                              hintText: 'Enter first name',
                              headerText: 'First Name',
                            ),
                            VTextField(
                              controller: _middleNameController,
                              hintText: 'Enter middle name',
                              headerText: 'Middle Name',
                            ),
                            VTextField(
                              controller: _lastNameController,
                              hintText: 'Enter last name',
                              headerText: 'Last Name',
                            ),
                            VDropdown(
                              headerText: 'Suffix (optional)',
                              hintText: 'Select suffix',
                              items: _suffixOptions,
                              value: _selectedSuffix,
                              onChanged: (value) {
                                setState(() {
                                  _selectedSuffix = value;
                                });
                              },
                            ),
                            AddressSuggestionField(
                              controller: _addressController,
                              hintText: 'Start typing; choose a suggestion or enter manually',
                              headerText: 'Address',
                            ),
                            const SizedBox(height: 14),
                            const VTextHeader(text: 'Contact Information'),
                            VTextField(
                              controller: _emailController,
                              hintText: 'Enter your email address',
                              headerText: 'Email',
                              keyboardType: TextInputType.emailAddress,
                            ),
                            VTextField(
                              controller: _phoneController,
                              hintText: '09XXXXXXXXX',
                              headerText: 'Phone Number',
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 14),
                            const VTextHeader(text: 'Security'),
                            VTextField(
                              controller: _passwordController,
                              hintText: 'Create a strong password',
                              headerText: 'Password',
                              isPassword: true,
                            ),
                            VTextField(
                              controller: _confirmPasswordController,
                              hintText: 'Re-enter your password',
                              headerText: 'Confirm Password',
                              isPassword: true,
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _isAgreed,
                                    activeColor: AppColors.primary,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        _isAgreed = value ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        text: 'I agree with all ',
                                        style: theme.textTheme.bodyMedium,
                                        children: const [
                                          TextSpan(
                                            text: 'Terms of Use',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              decoration:
                                                  TextDecoration.underline,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          TextSpan(text: ' and '),
                                          TextSpan(
                                            text: 'Privacy Policy',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              decoration:
                                                  TextDecoration.underline,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            VButton(
                              text: 'Register',
                              isLoading: _isLoading,
                              onPressed: _isLoading ? () {} : _register,
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Wrap(
                                spacing: 4,
                                children: [
                                  Text(
                                    'Have an account already?',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        RouteManager.loginPage,
                                      );
                                    },
                                    child: Text(
                                      'Login',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
