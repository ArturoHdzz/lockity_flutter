import 'package:flutter/material.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/screens/no_internet_screen.dart';
import 'package:lockity_flutter/services/connectivity_service.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({
    super.key,
    required this.child,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _hasConnection = true;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _listenToConnectivityChanges();
  }

  Future<void> _checkInitialConnection() async {
    final hasConnection = await ConnectivityService.hasInternetConnection();
    if (mounted) {
      setState(() {
        _hasConnection = hasConnection;
        _isChecking = false;
      });
    }
  }

  void _listenToConnectivityChanges() {
    ConnectivityService.connectivityStream.listen((hasConnection) {
      if (mounted && _hasConnection != hasConnection) {
        setState(() {
          _hasConnection = hasConnection;
        });
      }
    });
  }

  void _handleRetry() {
    setState(() {
      _isChecking = true;
    });
    _checkInitialConnection();
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: AppColors.primary,
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.buttons,
          ),
        ),
      );
    }

    if (!_hasConnection) {
      return NoInternetScreen(
        onRetry: _handleRetry,
      );
    }

    return widget.child;
  }
}