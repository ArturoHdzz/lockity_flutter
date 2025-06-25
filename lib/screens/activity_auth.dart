import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/custom_button.dart';
import 'package:lockity_flutter/components/divider_with_text.dart';
import 'package:lockity_flutter/components/oauth_webview.dart';
import 'package:lockity_flutter/components/app_scaffold.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/screens/home_screen.dart';
import 'package:lockity_flutter/services/oauth_service.dart';

class ActivityAuth extends StatefulWidget {
  const ActivityAuth({super.key});

  @override
  State<ActivityAuth> createState() => _ActivityAuthState();
}

class _ActivityAuthState extends State<ActivityAuth> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingAuth();
  }

  Future<void> _checkExistingAuth() async {
    final isAuthenticated = await OAuthService.isAuthenticated();
    
    if (isAuthenticated && mounted) {
      _navigateToHome();
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
      setState(() {
        _isLoading = true;
      });

      final authUrl = await OAuthService.buildAuthUrl(isRegister: isRegister);
      
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OAuthWebView(
              authUrl: authUrl,
              onSuccess: _onOAuthSuccess,
              onError: _onOAuthError,
            ),
          ),
        );
      }
    } catch (e) {
      _onOAuthError('Failed to start OAuth flow: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onOAuthSuccess(Map<String, dynamic> tokens) {
    Navigator.of(context).pop();
    _navigateToHome();
  }

  void _onOAuthError(String error) {
    Navigator.of(context).pop();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authentication failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const AppScaffold(
          showDrawer: true,
          body: HomeScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.fingerprint,
            size: 120,
            color: AppColors.background,
          ),
          const SizedBox(height: 60),
          const Text(
            'Hello',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w300,
              color: AppColors.text,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Get Started',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w400,
              color: AppColors.background,
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 80),
          _isLoading
              ? const CircularProgressIndicator(color: AppColors.buttons)
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