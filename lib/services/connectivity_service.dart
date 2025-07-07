import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:lockity_flutter/core/app_config.dart';

class ConnectivityService {
  static StreamController<bool>? _connectivityController;
  static Timer? _connectivityTimer;

  static Stream<bool> get connectivityStream {
    _connectivityController ??= StreamController<bool>.broadcast();
    _startConnectivityChecks();
    return _connectivityController!.stream;
  }

  static void _startConnectivityChecks() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) async {
        final isConnected = await hasInternetConnection();
        _connectivityController?.add(isConnected);
      },
    );
  }

  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResults = await Future.wait([
        _checkConnectivityToHost('google.com'),
        _checkConnectivityToHost('cloudflare.com'),
        _checkConnectivityToHost('microsoft.com'),
      ]);

      final hasBasicConnectivity = connectivityResults.any((result) => result);
      
      if (hasBasicConnectivity) {
        return await _canReachAppServer();
      }
      
      return false;
    } catch (e) {
      if (AppConfig.debugMode) {
        debugPrint('🌐 Connectivity check failed: $e');
      }
      return false;
    }
  }

  static Future<bool> _checkConnectivityToHost(String host) async {
    try {
      final result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _canReachAppServer() async {
    try {
      final baseUrl = AppConfig.baseUrl;
      final uri = Uri.parse(baseUrl);
      
      final socket = await Socket.connect(
        uri.host,
        uri.port,
        timeout: const Duration(seconds: 5),
      );
      socket.destroy();
      
      return true;
    } catch (e) {
      return await _hasGeneralInternetConnectivity();
    }
  }

  static Future<bool> _hasGeneralInternetConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static void dispose() {
    _connectivityTimer?.cancel();
    _connectivityController?.close();
    _connectivityController = null;
  }
}