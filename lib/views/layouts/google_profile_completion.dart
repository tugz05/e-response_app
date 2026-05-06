import 'package:e_response_app_nemsu/controllers/VTextFieldController.dart';
import 'package:e_response_app_nemsu/helpers/account_session.dart';
import 'package:e_response_app_nemsu/services/profile_completion_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/components/VButton.dart';
import 'package:e_response_app_nemsu/views/components/VDropDown.dart';
import 'package:e_response_app_nemsu/views/components/VTextField.dart';
import 'package:e_response_app_nemsu/views/components/VTextHeader.dart';
import 'package:e_response_app_nemsu/views/components/address_suggestion_field.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Collects fields Google Sign-In does not supply (and merges Google-parsed
/// names) before routing to identity / admin verification.
class GoogleProfileCompletionPage extends StatefulWidget {
  const GoogleProfileCompletionPage({super.key});

  @override
  State<GoogleProfileCompletionPage> createState() =>
      _GoogleProfileCompletionPageState();
}

class _GoogleProfileCompletionPageState
    extends State<GoogleProfileCompletionPage> {
  final VTextFieldController _firstNameController = VTextFieldController();
  final VTextFieldController _middleNameController = VTextFieldController();
  final VTextFieldController _lastNameController = VTextFieldController();
  final VTextFieldController _phoneController = VTextFieldController();
  final VTextFieldController _addressController = VTextFieldController();
  final VTextFieldController _emailDisplayController = VTextFieldController();

  String? _selectedSuffix;
  String _email = '';
  bool _loadingPrefs = true;
  bool _submitting = false;

  final ProfileCompletionService _profileService = ProfileCompletionService();

  final List<String> _suffixOptions = ['N/A', 'Jr', 'Sr', 'II', 'III', 'IV'];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _email = prefs.getString('email') ?? '';
      _emailDisplayController.textController.text = _email;
      _firstNameController.textController.text = prefs.getString('fname') ?? '';
      _middleNameController.textController.text =
          prefs.getString('mname') ?? '';
      _lastNameController.textController.text = prefs.getString('lname') ?? '';
      final sfx = prefs.getString('suffix') ?? '';
      _selectedSuffix =
          sfx.isEmpty ? 'N/A' : (_suffixOptions.contains(sfx) ? sfx : 'N/A');
      _phoneController.textController.text = prefs.getString('phone') ?? '';
      _addressController.textController.text =
          prefs.getString('address') ?? '';
      _loadingPrefs = false;
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailDisplayController.dispose();
    super.dispose();
  }

  String? _validate() {
    final f = _firstNameController.text.trim();
    final l = _lastNameController.text.trim();
    final m = _middleNameController.text.trim();
    final phone = _phoneController.text.trim();
    final addr = _addressController.text.trim();

    if (f.length < 2 || f.length > 200) {
      return 'First name must be between 2 and 200 characters.';
    }
    if (l.length < 2 || l.length > 200) {
      return 'Last name must be between 2 and 200 characters.';
    }
    if (m.isNotEmpty && (m.length < 2 || m.length > 200)) {
      return 'Middle name must be between 2 and 200 characters if provided.';
    }
    if (phone.length != 11 || !RegExp(r'^\d+$').hasMatch(phone)) {
      return 'Phone number must be exactly 11 digits.';
    }
    if (addr.length < 5) {
      return 'Please enter a complete address.';
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    setState(() {
      _submitting = true;
    });

    final suffix =
        _selectedSuffix == null || _selectedSuffix == 'N/A'
            ? null
            : _selectedSuffix;

    final result = await _profileService.submit(
      fname: _firstNameController.text.trim(),
      mname: _middleNameController.text.trim(),
      lname: _lastNameController.text.trim(),
      suffix: suffix,
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    if (result['ok'] == true) {
      final prefs = await SharedPreferences.getInstance();
      final status =
          prefs.getString(AccountSession.prefsKeyAccountStatus) ??
              'pending_verification';
      if (!mounted) {
        return;
      }
      await AccountSession.replaceRouteForLoginStatus(context, status);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ??
              'Unable to save profile. Please try again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child:
            _loadingPrefs
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.primaryAlt,
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    22,
                                    22,
                                    20,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'COMPLETE YOUR PROFILE',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: AppColors.secondary,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.85,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Details for verification',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Google sign-in does not include '
                                        'everything we need for admin review. '
                                        'Confirm your name, contact number, and '
                                        'address before continuing.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: AppColors.textMuted,
                                              height: 1.45,
                                            ),
                                      ),
                                      const SizedBox(height: 18),
                                      const VTextHeader(
                                        text: 'Personal information',
                                      ),
                                      VTextField(
                                        controller: _firstNameController,
                                        hintText: 'First name',
                                        headerText: 'First name',
                                        textInputAction: TextInputAction.next,
                                      ),
                                      VTextField(
                                        controller: _middleNameController,
                                        hintText: 'Middle name (optional)',
                                        headerText: 'Middle name',
                                        textInputAction: TextInputAction.next,
                                      ),
                                      VTextField(
                                        controller: _lastNameController,
                                        hintText: 'Last name',
                                        headerText: 'Last name',
                                        textInputAction: TextInputAction.next,
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
                                      const SizedBox(height: 8),
                                      VTextField(
                                        controller: _emailDisplayController,
                                        hintText: 'Email from Google',
                                        headerText: 'Email',
                                        enabled: false,
                                      ),
                                      const SizedBox(height: 8),
                                      const VTextHeader(
                                        text: 'Contact',
                                      ),
                                      VTextField(
                                        controller: _phoneController,
                                        hintText: '09XXXXXXXXX',
                                        headerText: 'Mobile number',
                                        keyboardType: TextInputType.phone,
                                        textInputAction: TextInputAction.next,
                                      ),
                                      AddressSuggestionField(
                                        controller: _addressController,
                                        hintText:
                                            'Start typing; choose a suggestion or enter manually',
                                        headerText: 'Address',
                                        textInputAction: TextInputAction.done,
                                      ),
                                      const SizedBox(height: 22),
                                      VButton(
                                        text: 'Continue to verification',
                                        isLoading: _submitting,
                                        onPressed:
                                            _submitting ? () {} : _submit,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
