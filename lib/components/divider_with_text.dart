import 'package:flutter/material.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';

class DividerWithText extends StatelessWidget {
  final String text;

  const DividerWithText({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.background.withValues(alpha: 0.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: AppTextStyles.dividerText,
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.background.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}