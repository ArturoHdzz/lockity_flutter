import 'package:flutter/material.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';
import 'package:lockity_flutter/services/navigation_service.dart';
import 'package:lockity_flutter/services/oauth_service.dart';
import 'package:lockity_flutter/services/notification_service.dart';
import 'package:lockity_flutter/services/user_service.dart'; // ✅ AGREGAR IMPORT
import 'package:lockity_flutter/screens/activity_auth.dart';
import 'package:lockity_flutter/components/app_scaffold.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.primary,
      child: Column(
        children: [
          const SizedBox(height: 60),
          _CloseButton(),
          const SizedBox(height: 40),
          ..._buildMenuItems(context),
          const Spacer(),
          _LogoutButton(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final menuItems = [
      _MenuItem(
        icon: Icons.home_outlined,
        title: 'Home',
        onTap: () => NavigationService.navigateToHome(context),
      ),
      _MenuItem(
        icon: Icons.person_outline,
        title: 'User',
        onTap: () => NavigationService.navigateToProfile(context),
      ),
      _MenuItem(
        icon: Icons.shield_outlined,
        title: 'My Lockers',
        onTap: () => NavigationService.navigateToMyLockers(context),
      ),
    ];

    return menuItems;
  }
}

class _CloseButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppColors.text,
        size: 24,
      ),
      title: Text(title, style: AppTextStyles.menuItem),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 8,
      ),
    );
  }
}

class _LogoutButton extends StatefulWidget {
  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _isLoggingOut
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppColors.buttons,
                strokeWidth: 2,
              ),
            )
          : const Icon(
              Icons.logout_outlined,
              color: AppColors.buttons,
              size: 24,
            ),
      title: Text(
        'Log Out',
        style: AppTextStyles.menuItemLogout,
      ),
      onTap: _isLoggingOut ? null : _handleLogout,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 8,
      ),
    );
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;

    setState(() => _isLoggingOut = true);
    
    try {
      print('🚪 Iniciando proceso de logout...');
      
      if (mounted) {
        Navigator.of(context).pop();
        print('✅ Drawer cerrado');
      }
      
      await _clearAllLocalDataImmediately();
      print('✅ Datos locales limpiados');
      
      if (mounted) {
        _navigateToAuthImmediate();
        print('✅ Navegación iniciada');
      }
      
      _performServerLogoutInBackground();
      
    } catch (e) {
      print('❌ Error en logout: $e');
      if (mounted) {
        await _clearAllLocalDataImmediately();
        _navigateToAuthImmediate();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  Future<void> _clearAllLocalDataImmediately() async {
    try {
      UserService.clearCache();
      
      await OAuthService.clearAllData();
      
      print('✅ Todos los datos locales limpiados');
    } catch (e) {
      print('⚠️ Error limpiando datos locales: $e');
    }
  }

  void _navigateToAuthImmediate() {
    try {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const AppScaffold(
              showDrawer: false,
              body: ActivityAuth(showRegistrationSuccess: false),
            ),
          ),
          (route) => false,
        );
        
        print('✅ Navegación a auth completada');
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            NotificationService.showSuccess(
              context,
              'Logout Successful',
              subtitle: 'You have been safely logged out',
            );
          }
        });
      }
    } catch (e) {
      print('❌ Error navegando a auth: $e');
    }
  }

  void _performServerLogoutInBackground() {
    Future(() async {
      try {
        print('🌐 Intentando logout del servidor...');
        final result = await OAuthService.logout();
        print('✅ Logout del servidor: ${result.message}');
      } catch (e) {
        print('⚠️ Error en logout del servidor: $e');
      }
    });
  }
}