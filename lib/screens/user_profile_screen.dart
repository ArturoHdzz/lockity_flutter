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

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: _provider.isUpdating
        ? const Center(child: CircularProgressIndicator(color: AppColors.buttons))
        : _provider.isInCooldown
            ? _buildCooldownButton()
            : CustomButton(
                text: 'Save Changes',
                onPressed: _provider.canUpdate ? _handleSave : null,
                isEnabled: _provider.canUpdate,
              ),
    );
  }

  Widget _buildCooldownButton() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule,
              color: AppColors.text.withOpacity(0.7),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Available in ${_provider.cooldownFormattedTime}',
              style: AppTextStyles.button.copyWith(
                color: AppColors.text.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Profile updated successfully'),
                  Text(
                    'Next update available in 30 minutes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
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
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.1,
        ),
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
      ),
    );
  }

  Widget _buildContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    final horizontalPadding = screenWidth < 360 
        ? 12.0 
        : screenWidth < 400 
            ? 16.0 
            : screenWidth > 600 
                ? 32.0 
                : 20.0;
    
    final verticalSpacing = screenHeight < 700 ? 20.0 : 40.0;
    final smallVerticalSpacing = screenHeight < 700 ? 12.0 : 24.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 32,
            ),
            child: Column(
              children: [
                SizedBox(height: verticalSpacing),
                _buildProfileIcon(),
                SizedBox(height: smallVerticalSpacing),
                if (_provider.user != null) _buildUserInfo(),
                SizedBox(height: verticalSpacing),
                _buildForm(),
                SizedBox(height: verticalSpacing),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileIcon() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    final iconSize = screenWidth < 360 
        ? 80.0 
        : screenWidth < 400 
            ? 90.0 
            : screenWidth > 600 
                ? 120.0 
                : 100.0;
    
    final personIconSize = iconSize * 0.5;

    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondary.withOpacity(0.3),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Icon(
        Icons.person, 
        size: personIconSize, 
        color: AppColors.secondary,
      ),
    );
  }

  Widget _buildUserInfo() {
    final user = _provider.user!;
    final screenHeight = MediaQuery.of(context).size.height;
    final smallSpacing = screenHeight < 700 ? 2.0 : 4.0;
    final mediumSpacing = screenHeight < 700 ? 6.0 : 8.0;
    final largeSpacing = screenHeight < 700 ? 8.0 : 12.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.05,
      ),
      child: Column(
        children: [
          Text(
            user.fullName,
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: smallSpacing),
          Text(
            user.email,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.text.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (user.hasEmailVerified) ...[
            SizedBox(height: mediumSpacing),
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
            SizedBox(height: largeSpacing),
            Text(
              'Roles: ${user.roles!.map((role) => role.role).join(', ')}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.text.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    final formPadding = screenWidth < 360 
        ? 16.0 
        : screenWidth < 400 
            ? 20.0 
            : screenWidth > 600 
                ? 32.0 
                : 24.0;
    
    final horizontalMargin = screenWidth < 360 
        ? 8.0 
        : screenWidth < 400 
            ? 12.0 
            : screenWidth > 600 
                ? 24.0 
                : 16.0;

    final verticalSpacing = screenHeight < 700 ? 16.0 : 24.0;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: screenWidth > 600 ? 500 : double.infinity,
      ),
      padding: EdgeInsets.all(formPadding),
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
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
            SizedBox(height: verticalSpacing),
            ..._buildFormFields(),
            SizedBox(height: verticalSpacing),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final fieldSpacing = screenHeight < 700 ? 12.0 : 16.0;
    
    final verticalPadding = screenHeight < 700 ? 12.0 : 16.0;

    return Container(
      margin: EdgeInsets.only(bottom: fieldSpacing),
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
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16, 
            vertical: verticalPadding,
          ),
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
}