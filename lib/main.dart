import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/app_scaffold.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/screens/activity_auth.dart';
import 'package:lockity_flutter/screens/home_screen.dart';
import 'package:lockity_flutter/services/oauth_service.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lockity',
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.primary,
      ),
      home: FutureBuilder<bool>(
        future: OAuthService.isAuthenticated(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppColors.primary,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.buttons),
              ),
            );
          }
          
          // Si está autenticado, ir directo al Home
          if (snapshot.data == true) {
            return const AppScaffold(
              showDrawer: true,
              body: HomeScreen(),
            );
          }
          
          // Si no está autenticado, mostrar pantalla de login
          return const AppScaffold(
            showDrawer: false,
            body: ActivityAuth(),
          );
        },
      ),
    );
  }
}