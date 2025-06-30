import 'package:flutter/material.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';
import 'package:lockity_flutter/screens/user_profile_screen.dart';
import 'package:lockity_flutter/screens/activity_auth.dart';
import 'package:lockity_flutter/components/app_scaffold.dart';
import 'package:lockity_flutter/services/oauth_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.primary,
      child: Column(
        children: [
          const SizedBox(height: 60),
          _buildCloseButton(context),
          const SizedBox(height: 40),
          _buildMenuItem(
            icon: Icons.home_outlined,
            title: 'Home',
            onTap: () => _navigateTo(context, '/home'),
          ),
          _buildMenuItem(
            icon: Icons.person_outline,
            title: 'User',
            onTap: () => _navigateToProfile(context),
          ),
          _buildMenuItem(
            icon: Icons.shield_outlined,
            title: 'My Lockers',
            onTap: () => _navigateTo(context, '/lockers'),
          ),
          _buildMenuItem(
            icon: Icons.notifications_outlined,
            title: 'Record',
            onTap: () => _navigateTo(context, '/record'),
          ),
          const Spacer(),
          _buildMenuItem(
            icon: Icons.logout_outlined,
            title: 'Log Out',
            isLogout: true,
            onTap: () => _handleLogout(context),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.close,
            color: AppColors.text,
            size: 30,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isLogout ? AppColors.buttons : AppColors.text,
        size: 24,
      ),
      title: Text(
        title,
        style: isLogout ? AppTextStyles.menuItemLogout : AppTextStyles.menuItem,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    );
  }

  void _navigateTo(BuildContext context, String route) {
    Navigator.of(context).pop();
    debugPrint('Navigate to: $route');
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const UserProfileScreen()),
    );
  }

Future<void> _handleLogout(BuildContext context) async {
  Navigator.of(context).pop();
  
  await OAuthService.logout();
  
  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const AppScaffold(
          showDrawer: false,
          body: ActivityAuth(),
        ),
      ),
      (route) => false,
    );
  }
}
}