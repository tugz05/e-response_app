import 'dart:convert';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userId = '';
  String name = '';
  String mobile = '';
  String email = '';
  String address = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('id') ?? '';
      name = prefs.getString('name') ?? '';
      mobile = prefs.getString('phone') ?? '';
      email = prefs.getString('email') ?? '';
      address = prefs.getString('address') ?? '';
    });
  }

  Future<void> _updateProfile() async {
    setState(() => isLoading = true);
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
      setState(() => isLoading = false);
      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('email', email);
        prefs.setString('phone', mobile);
        prefs.setString('address', address);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profile updated successfully!"),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        String error = 'Failed to update profile';
        try {
          final data = json.decode(res.body);
          if (data['message'] != null) error = data['message'];
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  void _editField(String fieldName, String label, String initialValue, ValueChanged<String> onSaved) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: Text('Save'),
            onPressed: () {
              onSaved(controller.text.trim());
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      backgroundColor: AppColors.primary,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Picture and Name Section
              Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: AppColors.primary,
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: AppColors.primary,
                        ),
                      ),
                      // Optionally, you can add profile pic editing here
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Editable Information Section
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  EditableInfoRow(
                    label: "Name",
                    value: name,
                    showEdit: false, // No edit button for Name
                    onEdit: () {},   // Won't be called
                  ),
                  const SizedBox(height: 20),
                  EditableInfoRow(
                    label: "Mobile Number",
                    value: mobile,
                    onEdit: () {
                      _editField("mobile", "Mobile Number", mobile, (v) async {
                        setState(() => mobile = v);
                        final prefs = await SharedPreferences.getInstance();
                        prefs.setString('phone', v);
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  EditableInfoRow(
                    label: "Email",
                    value: email,
                    onEdit: () {
                      _editField("email", "Email", email, (v) async {
                        setState(() => email = v);
                        final prefs = await SharedPreferences.getInstance();
                        prefs.setString('email', v);
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  EditableInfoRow(
                    label: "Address",
                    value: address,
                    onEdit: () {
                      _editField("address", "Address", address, (v) async {
                        setState(() => address = v);
                        final prefs = await SharedPreferences.getInstance();
                        prefs.setString('address', v);
                      });
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      icon: isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh, color: Colors.white),
                      label: Text(
                        isLoading ? "Updating..." : "Update",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: isLoading ? null : _updateProfile,
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class EditableInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onEdit;
  final bool showEdit;

  const EditableInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.onEdit,
    this.showEdit = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textMuted,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (showEdit)
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.textMuted),
            onPressed: onEdit,
          ),
      ],
    );
  }
}
