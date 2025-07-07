import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/custom_button.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';
import 'package:lockity_flutter/services/connectivity_service.dart';

class NoInternetScreen extends StatefulWidget {
  final VoidCallback? onRetry;

  const NoInternetScreen({
    super.key,
    this.onRetry,
  });

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    setState(() {
      _isRetrying = true;
    });

    final hasConnection = await ConnectivityService.hasInternetConnection();
    
    if (hasConnection) {
      widget.onRetry?.call();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Still no internet connection. Please check your network.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isRetrying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                    MediaQuery.of(context).padding.top - 
                    MediaQuery.of(context).padding.bottom - 40,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildNoInternetIcon(),
                  const SizedBox(height: 30),
                  _buildTitle(),
                  const SizedBox(height: 16),
                  _buildSubtitle(),
                  const SizedBox(height: 40),
                  _buildRetryButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoInternetIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondary.withValues(alpha: 0.3),
        border: Border.all(
          color: AppColors.text.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Icon(
        Icons.wifi_off,
        size: 50,
        color: AppColors.text.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'No Internet\nConnection',
      style: AppTextStyles.headingMedium.copyWith(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
        fontSize: 28,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Please check your internet connection and try again.',
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.text.withValues(alpha: 0.8),
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildRetryButton() {
    return _isRetrying
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppColors.buttons,
              strokeWidth: 2,
            ),
          )
        : CustomButton(
            text: 'Try Again',
            onPressed: _handleRetry,
          );
  }
}