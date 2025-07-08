import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/app_scaffold.dart';
import 'package:lockity_flutter/screens/activity_auth.dart';
import 'package:lockity_flutter/screens/home_screen.dart';
import 'package:lockity_flutter/screens/user_profile_screen.dart';
import 'package:lockity_flutter/screens/my_lockers_screen.dart';
import 'package:lockity_flutter/screens/record_screen.dart';

class NavigationService {
  static void navigateToHome(BuildContext context) {
    _navigateWithDrawer(context, const HomeScreen());
  }

  static void navigateToProfile(BuildContext context) {
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const UserProfileScreen(),
        ),
      );
    } catch (e) {
      // Manejar error de navegación
    }
  }

  static void navigateToMyLockers(BuildContext context) {
    _navigateWithDrawer(context, const MyLockersScreen());
  }

  static void navigateToRecord(BuildContext context) {
    _navigateWithDrawer(context, const RecordScreen());
  }

  static void navigateToAuth(BuildContext context) {
    try {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const AppScaffold(
            showDrawer: false,
            body: ActivityAuth(showRegistrationSuccess: false),
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      //
    }
  }

  static void _navigateWithDrawer(BuildContext context, Widget screen) {
    try {
      Navigator.of(context).pop();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AppScaffold(
            showDrawer: true,
            body: screen,
          ),
        ),
      );
    } catch (e) {
      //
    }
  }

  NavigationService._();
}