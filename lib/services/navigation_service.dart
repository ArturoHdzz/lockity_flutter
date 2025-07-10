import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/app_scaffold.dart';
import 'package:lockity_flutter/screens/activity_auth.dart';
import 'package:lockity_flutter/screens/home_screen.dart';
import 'package:lockity_flutter/screens/user_profile_screen.dart';
import 'package:lockity_flutter/screens/my_lockers_screen.dart';
import 'package:lockity_flutter/screens/record_screen.dart';

class NavigationService {
  static NavigationScreen _currentScreen = NavigationScreen.home;
  static bool _isProfileOpen = false;

  static void navigateToHome(BuildContext context) {
    if (_isProfileOpen) {
      _isProfileOpen = false;
      _currentScreen = NavigationScreen.home;
      
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const AppScaffold(
            showDrawer: true,
            body: HomeScreen(),
          ),
        ),
      );
      return;
    }

    if (_currentScreen == NavigationScreen.home) {
      _safeNavigatorPop(context);
      return;
    }

    _currentScreen = NavigationScreen.home;
    _navigateWithDrawer(context, const HomeScreen());
  }

  static void navigateToProfile(BuildContext context) {
    if (_isProfileOpen) {
      _safeNavigatorPop(context);
      return;
    }

    _isProfileOpen = true;
    _safeNavigatorPop(context);
    
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const UserProfileScreen()),
    ).then((_) {
      _isProfileOpen = false;
    });
  }

  static void navigateToMyLockers(BuildContext context) {
    if (_isProfileOpen) {
      _isProfileOpen = false;
      _currentScreen = NavigationScreen.lockers;
      
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const AppScaffold(
            showDrawer: true,
            body: MyLockersScreen(),
          ),
        ),
      );
      return;
    }

    if (_currentScreen == NavigationScreen.lockers) {
      _safeNavigatorPop(context);
      return;
    }

    _currentScreen = NavigationScreen.lockers;
    _navigateWithDrawer(context, const MyLockersScreen());
  }

  static void navigateToRecord(BuildContext context) {
    if (_isProfileOpen) {
      _isProfileOpen = false;
      _currentScreen = NavigationScreen.record;
      
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const AppScaffold(
            showDrawer: true,
            body: RecordScreen(),
          ),
        ),
      );
      return;
    }

    if (_currentScreen == NavigationScreen.record) {
      _safeNavigatorPop(context);
      return;
    }

    _currentScreen = NavigationScreen.record;
    _navigateWithDrawer(context, const RecordScreen());
  }

  static void navigateToAuth(BuildContext context) {
    try {
      _currentScreen = NavigationScreen.auth;
      _isProfileOpen = false;
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
      // Error handling
    }
  }

  static void _safeNavigatorPop(BuildContext context) {
    try {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Error handling
    }
  }

  static void _navigateWithDrawer(BuildContext context, Widget screen) {
    try {
      _safeNavigatorPop(context);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AppScaffold(
            showDrawer: true,
            body: screen,
          ),
        ),
      );
    } catch (e) {
      // Error handling
    }
  }

  static NavigationScreen get currentScreen => _currentScreen;
  static bool get isProfileOpen => _isProfileOpen;
  static String get currentScreenName => _currentScreen.name;

  static void setCurrentScreen(NavigationScreen screen) {
    _currentScreen = screen;
    _isProfileOpen = false;
  }

  NavigationService._();
}

enum NavigationScreen {
  home,
  lockers,
  record,
  auth;
}