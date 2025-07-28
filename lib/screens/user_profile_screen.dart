import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/app_scaffold.dart';
import 'package:lockity_flutter/components/custom_button.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';
import 'package:lockity_flutter/models/user.dart';
import 'package:lockity_flutter/providers/user_profile_provider.dart';
import 'package:lockity_flutter/repositories/user_repository_impl.dart';
import 'package:lockity_flutter/use_cases/get_current_user_use_case.dart';
import 'package:lockity_flutter/use_cases/update_user_use_case.dart';
import 'package:lockity_flutter/utils/text_formatters.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final UserProfileProvider _provider;
  final _formKey = GlobalKey<FormState>();
  final _controllers = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeProvider();
    _loadUserProfile();
  }

  void _initializeProvider() {
    final repository = UserRepositoryImpl();
    _provider = UserProfileProvider(
      getCurrentUserUseCase: GetCurrentUserUseCase(repository),
      updateUserUseCase: UpdateUserUseCase(repository),
    );
    _provider.addListener(_onProviderStateChanged);
  }

  void _onProviderStateChanged() {
    if (!mounted) return;

    switch (_provider.state) {
      case UserProfileState.loaded:
        if (_provider.user != null) _populateFields(_provider.user!);
        break;
      case UserProfileState.updated:
        _showSuccessMessage();
        break;
      case UserProfileState.error:
        _showErrorMessage(_provider.errorMessage ?? 'An error occurred');
        break;
      default:
        break;
    }
  }

  void _populateFields(User user) {
    _controllers[0].text = user.name;
    _controllers[1].text = user.lastName;
    _controllers[2].text = user.secondLastName;
  }

  Future<void> _loadUserProfile() => _provider.loadUserProfile();

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await _provider.updateUserProfile(
      name: TextFormatters.formatName(_controllers[0].text),
      lastName: TextFormatters.formatName(_controllers[1].text),
      secondLastName: TextFormatters.formatName(_controllers[2].text),
    );

    if (success) {
      FocusScope.of(context).unfocus();
      await _provider.loadUserProfile();
    }
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Profile updated successfully'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            _provider.clearError();
            _loadUserProfile();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderStateChanged);
    _provider.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'User Profile',
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_provider.isLoading) return _buildLoadingState();
    if (_provider.hasError && !_provider.hasUser) return _buildErrorState();
    return _buildContent();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.buttons),
          SizedBox(height: 16),
          Text('Loading profile...', style: TextStyle(color: AppColors.text)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.text, size: 48),
          const SizedBox(height: 16),
          Text('Failed to load profile', style: AppTextStyles.bodyLarge),
          const SizedBox(height: 8),
          Text(
            _provider.errorMessage ?? 'Unknown error',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadUserProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttons,
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildProfileIcon(),
          const SizedBox(height: 24),
          if (_provider.user != null) _buildUserInfo(),
          const SizedBox(height: 40),
          _buildForm(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondary.withOpacity(0.3),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: const Icon(Icons.person, size: 50, color: AppColors.secondary),
    );
  }

  Widget _buildUserInfo() {
    final user = _provider.user!;
    return Column(
      children: [
        Text(
          user.fullName,
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.text.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
        ),
        if (user.hasEmailVerified) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              Text(
                'Email verified',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.green),
              ),
            ],
          ),
        ],
        if (user.roles != null && user.roles!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Roles: ${user.roles!.map((role) => role.role).join(', ')}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.text.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Profile',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 24),
            ..._buildFormFields(),
            const SizedBox(height: 24),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    final fieldData = [
      ('First Name', _validateName),
      ('Last Name', _validateName),
      ('Second Last Name', _validateName),
    ];

    return fieldData.asMap().entries.map((entry) {
      final index = entry.key;
      final (hintText, validator) = entry.value;
      
      return _buildTextField(
        controller: _controllers[index],
        hintText: hintText,
        keyboardType: index == 3 ? TextInputType.emailAddress : TextInputType.text,
        validator: validator,
      );
    }).toList();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required';
    if (value.trim().length < 3) return 'Must be at least 3 characters long';
    if (value.trim().length > 100) return 'Too long (maximum 100 characters)';
    if (!RegExp(r"^[a-zA-ZàáâäãåąčćęèéêëėįìíîïłńòóôöõøùúûüųūÿýżźñçčšžÀÁÂÄÃÅĄĆČĖĘÈÉÊËÌÍÎÏĮŁŃÒÓÔÖÕØÙÚÛÜŲŪŸÝŻŹÑßÇŒÆČŠŽ\s'.-]+$").hasMatch(value.trim())) {
      return 'Only letters and spaces are allowed';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: AppTextStyles.textField,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.hintText,
          filled: true,
          fillColor: Colors.transparent,
          border: _buildInputBorder(AppColors.background.withOpacity(0.3), 1),
          enabledBorder: _buildInputBorder(AppColors.background.withOpacity(0.3), 1),
          focusedBorder: _buildInputBorder(AppColors.buttons, 2),
          errorBorder: _buildInputBorder(Colors.red, 1),
          focusedErrorBorder: _buildInputBorder(Colors.red, 2),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  OutlineInputBorder _buildInputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: _provider.isUpdating
        ? const Center(child: CircularProgressIndicator(color: AppColors.buttons))
        : CustomButton(text: 'Save Changes', onPressed: _handleSave),
    );
  }
}