import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/app_scaffold.dart';
import 'package:lockity_flutter/components/custom_text_field.dart';
import 'package:lockity_flutter/components/custom_button.dart';
import 'package:lockity_flutter/core/app_colors.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _secondLastNameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _secondLastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleSave() {
    debugPrint('Name: ${_nameController.text}');
    debugPrint('Last Name: ${_lastNameController.text}');
    debugPrint('Second Last Name: ${_secondLastNameController.text}');
    debugPrint('Email: ${_emailController.text}');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully'),
        backgroundColor: AppColors.buttons,
      ),
    );
  }

  Widget _buildProfileIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.background.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: const Icon(
        Icons.person_outline,
        size: 60,
        color: AppColors.background,
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.background.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          CustomTextField(
            hintText: 'Name',
            controller: _nameController,
          ),
          CustomTextField(
            hintText: 'Last Name',
            controller: _lastNameController,
          ),
          CustomTextField(
            hintText: 'Second Last Name',
            controller: _secondLastNameController,
          ),
          CustomTextField(
            hintText: 'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Save Changes',
            onPressed: _handleSave,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'User Profile',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 40),
            _buildProfileIcon(),
            const SizedBox(height: 40),
            _buildForm(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}