import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/custom_button.dart';
import 'package:lockity_flutter/components/divider_with_text.dart';
import 'package:lockity_flutter/components/oauth_webview.dart';
import 'package:lockity_flutter/components/app_scaffold.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_icons.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';
import 'package:lockity_flutter/screens/home_screen.dart';
import 'package:lockity_flutter/services/oauth_service.dart';

class ActivityAuth extends StatefulWidget {
  final bool showRegistrationSuccess;
  
  const ActivityAuth({
    super.key,
    this.showRegistrationSuccess = false, 
  });

  @override
  State<ActivityAuth> createState() => _ActivityAuthState();
}

class _ActivityAuthState extends State<ActivityAuth> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      await OAuthService.clearAllData();
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (widget.showRegistrationSuccess) {
        _showRegistrationSuccessMessage();
      }
      
      await _checkExistingAuth();
    } catch (e) {
      // 
    }
  }

  void _showRegistrationSuccessMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Account Created Successfully!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'You can now sign in with your credentials',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    });
  }

  Future<void> _checkExistingAuth() async {
    try {
      final isAuthenticated = await OAuthService.isAuthenticated();
      
      if (isAuthenticated && mounted) {
        _navigateToHome();
      }
    } catch (e) {
      // 
    }
  }

  Future<void> _handleLogin() async {
    await _startOAuthFlow(isRegister: false);
  }

  Future<void> _handleRegister() async {
    await _startOAuthFlow(isRegister: true);
  }

  Future<void> _startOAuthFlow({required bool isRegister}) async {
    try {
      setState(() => _isLoading = true);

      await OAuthService.clearAllData();
      await Future.delayed(const Duration(milliseconds: 100));

      final authUrl = await OAuthService.buildAuthorizationUrl(isRegister: isRegister);
      
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OAuthWebView(
              authUrl: authUrl,
              onSuccess: _onOAuthSuccess,
              onError: _onOAuthError,
              onRegistrationSuccess: isRegister ? _onRegistrationSuccess : null,
              isRegister: isRegister,
            ),
          ),
        );
      }
    } catch (e) {
      _onOAuthError('Failed to start OAuth flow: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onOAuthSuccess(AuthToken token) {
    if (mounted) {
      Navigator.of(context).pop();
      _navigateToHome();
    }
  }

  void _onOAuthError(String error) {
    if (mounted) {
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authentication failed: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _onRegistrationSuccess() {
    if (mounted) {
      Navigator.of(context).pop(); 
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const AppScaffold(
            showDrawer: false,
            body: ActivityAuth(showRegistrationSuccess: true),
          ),
        ),
      );
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const AppScaffold(
            showDrawer: true,
            body: HomeScreen(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            AppIcons.logo,
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 60),
          Text(
            'Hello',
            style: AppTextStyles.headingLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Get Started',
            style: AppTextStyles.headingMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 80),
          _isLoading
              ? const Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.buttons),
                    SizedBox(height: 16),
                    Text(
                      'Setting up authentication...',
                      style: TextStyle(color: AppColors.text),
                    ),
                  ],
                )
              : Column(
                  children: [
                    CustomButton(
                      text: 'Sign In',
                      onPressed: _handleLogin,
                    ),
                    const SizedBox(height: 24),
                    const DividerWithText(text: 'Or'),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'Sign Up',
                      onPressed: _handleRegister,
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}