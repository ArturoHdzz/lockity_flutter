import 'package:flutter/material.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_icons.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';

class LoadingScreen extends StatelessWidget {
  final String? message;
  final String? subtitle;

  const LoadingScreen({
    super.key,
    this.message,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(),
            const SizedBox(height: 40),
            _buildLoadingIndicator(),
            const SizedBox(height: 32),
            _buildMainMessage(),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              _buildSubtitle(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      AppIcons.logo,
      width: 80,
      height: 80,
      fit: BoxFit.contain,
    );
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        color: AppColors.buttons,
        strokeWidth: 3,
      ),
    );
  }

  Widget _buildMainMessage() {
    return Text(
      message ?? 'Loading Lockity...',
      style: AppTextStyles.bodyLarge,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle() {
    return Text(
      subtitle!,
      style: AppTextStyles.subtitle,
      textAlign: TextAlign.center,
    );
  }
}