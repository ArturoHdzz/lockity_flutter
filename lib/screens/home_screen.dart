import 'package:flutter/material.dart';
import 'package:lockity_flutter/core/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Welcome to Home Screen',
        style: TextStyle(
          color: AppColors.text,
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}