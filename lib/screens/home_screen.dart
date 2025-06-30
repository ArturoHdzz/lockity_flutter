import 'package:flutter/material.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Welcome to Home Screen',
        style: AppTextStyles.headingSmall,
      ),
    );
  }
}