import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/app_drawer.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final bool showDrawer;

  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.showDrawer = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: showDrawer ? _buildAppBar() : null,
      drawer: showDrawer ? const AppDrawer() : null,
      body: body,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      title: title != null
          ? Text(
              title!,
              style: AppTextStyles.appBarTitle,
            )
          : null,
      iconTheme: const IconThemeData(color: AppColors.text),
    );
  }
}