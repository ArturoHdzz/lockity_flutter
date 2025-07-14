import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockity_flutter/components/app_scaffold.dart';
import 'package:lockity_flutter/components/connectivity_wrapper.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_config.dart'; 
import 'package:lockity_flutter/screens/activity_auth.dart';
import 'package:lockity_flutter/screens/home_screen.dart';
import 'package:lockity_flutter/screens/loading_screen.dart';
import 'package:lockity_flutter/services/oauth_service.dart';
import 'package:lockity_flutter/services/navigation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await AppConfig.load();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.primary,
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: AppBarTheme(
          titleTextStyle: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
          ),
        ),
      ),
      home: ConnectivityWrapper(
        child: FutureBuilder<bool>(
          future: _checkAuthWithTimeout(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen(
                message: 'Initializing Lockity',
                subtitle: 'Verifying security credentials...',
              );
            }
            if (snapshot.data == true) {
              NavigationService.setCurrentScreen(NavigationScreen.home);
              return const AppScaffold(
                showDrawer: true,
                body: HomeScreen(),
              );
            }
            return const AppScaffold(
              showDrawer: false,
              body: ActivityAuth(),
            );
          },
        ),
      ),
    );
  }

  Future<bool> _checkAuthWithTimeout() async {
    try {
      return await OAuthService.isAuthenticated()
          .timeout(Duration(seconds: AppConfig.authTimeout));
    } catch (e) {
      return false;
    }
  }
}