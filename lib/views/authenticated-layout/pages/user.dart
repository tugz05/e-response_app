import 'dart:convert';

import 'package:e_response_app_nemsu/controllers/VTextFieldController.dart';
import 'package:e_response_app_nemsu/helpers/logout.dart';
import 'package:e_response_app_nemsu/services/report_history_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/components/VButton.dart';
import 'package:e_response_app_nemsu/views/components/VTextField.dart';
import 'package:e_response_app_nemsu/views/components/verification_selfie_avatar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _UserSection { overview, profileDetails, reportHistory, changePassword }

class UserPage extends StatefulWidget {
  const UserPage({super.key, this.standalone = false});

  final bool standalone;

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final VTextFieldController _currentPasswordController =
      VTextFieldController();
  final VTextFieldController _newPasswordController = VTextFieldController();

  _UserSection _section = _UserSection.overview;

  String userId = '';
  String name = 'Loading...';
  String email = 'Loading...';
  String mobile = '';
  String address = '';
  String? _selfiePath;

  final ReportHistoryService _reportHistoryService = ReportHistoryService();

  bool _isUpdatingProfile = false;
  bool _isChangingPassword = false;
  bool _isLoadingTransactions = false;
  String? _transactionError;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      userId = prefs.getString('id') ?? '';
      name = prefs.getString('name') ?? 'Unknown User';
      email = prefs.getString('email') ?? '';
      mobile = prefs.getString('phone') ?? '';
      address = prefs.getString('address') ?? '';
      _selfiePath = prefs.getString('img_selfie');
    });
  }

  Future<void> _refreshCurrentSection() async {
    await _loadUserDetails();
    if (_section == _UserSection.reportHistory) {
      await _fetchTransactions();
    }
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : null,
      ),
    );
  }

  String _maskEmail(String value) {
    final atIdx = value.indexOf('@');
    if (atIdx <= 1) {
      return '*' * value.length;
    }
    return '${value[0]}${'*' * (atIdx - 1)}${value.substring(atIdx)}';
  }

  void _openSection(_UserSection section) {
    setState(() {
      _section = section;
    });

    if (section == _UserSection.reportHistory) {
      _fetchTransactions();
    }
  }

  Future<void> _fetchTransactions() async {
    if (userId.isEmpty) {
      await _loadUserDetails();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingTransactions = true;
      _transactionError = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final result = await _reportHistoryService.fetchForUser(
      userId,
      bearerToken: token,
    );

    if (!mounted) {
      return;
    }

    if (!result.isSuccess) {
      setState(() {
        _transactionError = result.errorMessage;
        _isLoadingTransactions = false;
        _transactions = [];
      });
      return;
    }

    setState(() {
      _transactions = List<dynamic>.from(result.items ?? []);
      _isLoadingTransactions = false;
    });
  }

  Future<void> _updateProfile() async {
    setState(() => _isUpdatingProfile = true);

    final uri = Uri.parse('https://cdrrmo-tandag.com/api/v1/profile');
    final body = json.encode({
      'id': userId,
      'email': email,
      'phone': mobile,
      'address': address,
    });

    try {
      final res = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      );

      if (!mounted) {
        return;
      }

      setState(() => _isUpdatingProfile = false);

      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('email', email);
        await prefs.setString('phone', mobile);
        await prefs.setString('address', address);
        _showMessage('Profile updated successfully!', success: true);
      } else {
        String error = 'Failed to update profile';
        try {
          final data = json.decode(res.body);
          if (data['message'] != null) {
            error = data['message'].toString();
          }
        } catch (_) {}
        _showMessage(error);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isUpdatingProfile = false);
      _showMessage('Network error: $error');
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty) {
      _showMessage('Please fill in all fields.');
      return;
    }
    if (newPassword.length < 6) {
      _showMessage('New password must be at least 6 characters.');
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('id');
      if (currentUserId == null || currentUserId.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() => _isChangingPassword = false);
        _showMessage('User not found.');
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
          'id': currentUserId,
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      if (!mounted) {
        return;
      }

      setState(() => _isChangingPassword = false);

      if (response.statusCode == 200) {
        _currentPasswordController.text = '';
        _newPasswordController.text = '';
        _showMessage('Password changed successfully!', success: true);
      } else {
        String msg = 'Failed to change password';
        try {
          final data = json.decode(response.body);
          if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        } catch (_) {}
        _showMessage(msg);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isChangingPassword = false);
      _showMessage('Error: $error');
    }
  }

  void _editField(
    String label,
    String initialValue,
    ValueChanged<String> onSaved,
  ) {
    final controller = TextEditingController(text: initialValue);
    String? errorText;
    final TextInputType keyboardType = switch (label) {
      'Email' => TextInputType.emailAddress,
      'Mobile Number' => TextInputType.phone,
      _ => TextInputType.streetAddress,
    };
    final String helperText = switch (label) {
      'Email' => 'Use an active email address you can access.',
      'Mobile Number' => 'Enter a number responders can contact if needed.',
      'Address' => 'Provide the address linked to your account.',
      _ => 'Update your information below.',
    };

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom + 12,
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                void submit() {
                  final String value = controller.text.trim();
                  if (value.isEmpty) {
                    setModalState(() {
                      errorText = '$label cannot be empty.';
                    });
                    return;
                  }

                  onSaved(value);
                  Navigator.pop(ctx);
                }

                return SafeArea(
                  top: false,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowSoft,
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 42,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.border,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Edit $label',
                                        style: Theme.of(
                                          ctx,
                                        ).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        helperText,
                                        style: Theme.of(
                                          ctx,
                                        ).textTheme.bodyMedium?.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: controller,
                              autofocus: true,
                              keyboardType: keyboardType,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) {
                                if (errorText != null) {
                                  setModalState(() {
                                    errorText = null;
                                  });
                                }
                              },
                              onSubmitted: (_) => submit(),
                              decoration: InputDecoration(
                                labelText: label,
                                errorText: errorText,
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy h:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _sectionTitle() {
    switch (_section) {
      case _UserSection.profileDetails:
        return 'Profile Details';
      case _UserSection.reportHistory:
        return 'Report History';
      case _UserSection.changePassword:
        return 'Change Password';
      case _UserSection.overview:
        return 'My Profile';
    }
  }

  String _sectionSubtitle() {
    switch (_section) {
      case _UserSection.profileDetails:
        return 'Review and update your account information.';
      case _UserSection.reportHistory:
        return 'Track the emergency reports you already submitted.';
      case _UserSection.changePassword:
        return 'Update your password without leaving the profile tab.';
      case _UserSection.overview:
        return 'Manage your account details and security settings.';
    }
  }

  Widget _buildOverview(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                VerificationSelfieAvatar(
                  displayName: name,
                  selfiePath: _selfiePath,
                  radius: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _maskEmail(email),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Account',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _ProfileActionCard(
          icon: Icons.badge_outlined,
          title: 'Profile Details',
          subtitle: 'Update your email, phone number, and address.',
          onTap: () => _openSection(_UserSection.profileDetails),
        ),
        _ProfileActionCard(
          icon: Icons.history_toggle_off_rounded,
          title: 'Report History',
          subtitle: 'Review your recent emergency reports.',
          onTap: () => _openSection(_UserSection.reportHistory),
        ),
        _ProfileActionCard(
          icon: Icons.lock_outline_rounded,
          title: 'Change Password',
          subtitle: 'Keep your account secure.',
          onTap: () => _openSection(_UserSection.changePassword),
        ),
        const SizedBox(height: 24),
        Text(
          'Session',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        const LogoutAccountTile(),
      ],
    );
  }

  Widget _buildProfileDetails(ThemeData theme) {
    return Column(
      children: [
        _EditableDetailCard(
          label: 'Full Name',
          value: name,
          icon: Icons.person_outline_rounded,
          showEdit: false,
          onEdit: () {},
        ),
        _EditableDetailCard(
          label: 'Mobile Number',
          value: mobile.isEmpty ? 'No mobile number added' : mobile,
          icon: Icons.phone_outlined,
          onEdit: () {
            _editField('Mobile Number', mobile, (value) {
              setState(() {
                mobile = value;
              });
            });
          },
        ),
        _EditableDetailCard(
          label: 'Email',
          value: email.isEmpty ? 'No email added' : email,
          icon: Icons.alternate_email_rounded,
          onEdit: () {
            _editField('Email', email, (value) {
              setState(() {
                email = value;
              });
            });
          },
        ),
        _EditableDetailCard(
          label: 'Address',
          value: address.isEmpty ? 'No address added' : address,
          icon: Icons.location_on_outlined,
          onEdit: () {
            _editField('Address', address, (value) {
              setState(() {
                address = value;
              });
            });
          },
        ),
        const SizedBox(height: 14),
        VButton(
          onPressed: _isUpdatingProfile ? () {} : _updateProfile,
          text: 'Save Changes',
          isLoading: _isUpdatingProfile,
        ),
      ],
    );
  }

  Widget _buildReportHistory(ThemeData theme) {
    if (_isLoadingTransactions) {
      return const Padding(
        padding: EdgeInsets.only(top: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_transactionError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            _transactionError!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'No transactions found.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
    }

    return Column(
      children:
          _transactions.map((tx) {
            final type = tx['type'] ?? 'N/A';
            final status = tx['status'] ?? 'N/A';
            final details = tx['details'] ?? '';
            final reportAddress = tx['address'] ?? '';
            final createdAt = tx['created_at'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(
                        type.toString().toLowerCase() == 'message'
                            ? Icons.message_outlined
                            : Icons.call_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.toString(),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (details.toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Details: $details'),
                          ],
                          if (reportAddress.toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Address: $reportAddress'),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            'Status: $status',
                            style: TextStyle(
                              color:
                                  status.toString().toLowerCase() == 'pending'
                                      ? AppColors.warning
                                      : status.toString().toLowerCase() ==
                                          'completed'
                                      ? AppColors.success
                                      : AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(createdAt.toString()),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildChangePassword() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            VTextField(
              hintText: 'Current Password',
              controller: _currentPasswordController,
              isPassword: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            VTextField(
              hintText: 'New Password',
              controller: _newPasswordController,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_isChangingPassword) {
                  _changePassword();
                }
              },
            ),
            const SizedBox(height: 22),
            VButton(
              onPressed: _isChangingPassword ? () {} : _changePassword,
              text: 'Update Password',
              isLoading: _isChangingPassword,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionBody(ThemeData theme) {
    switch (_section) {
      case _UserSection.profileDetails:
        return _buildProfileDetails(theme);
      case _UserSection.reportHistory:
        return _buildReportHistory(theme);
      case _UserSection.changePassword:
        return _buildChangePassword();
      case _UserSection.overview:
        return _buildOverview(theme);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget content = RefreshIndicator(
      onRefresh: _refreshCurrentSection,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          if (_section != _UserSection.overview) ...[
            TextButton.icon(
              onPressed: () => _openSection(_UserSection.overview),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.primary,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to account'),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            _sectionTitle(),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _sectionSubtitle(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          _buildSectionBody(theme),
        ],
      ),
    );

    if (!widget.standalone) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: content,
    );
  }
}

class _ProfileActionCard extends StatelessWidget {
  const _ProfileActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableDetailCard extends StatelessWidget {
  const _EditableDetailCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.onEdit,
    this.showEdit = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onEdit;
  final bool showEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (showEdit)
              TextButton(onPressed: onEdit, child: const Text('Edit')),
          ],
        ),
      ),
    );
  }
}
