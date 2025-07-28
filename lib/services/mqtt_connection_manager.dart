import 'dart:async';
import 'package:flutter/foundation.dart';
import 'mqtt_service.dart';

class MqttConnectionManager extends ChangeNotifier {
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  Future<void> connect({required String serialNumber}) async {
    if (_isConnecting || _isConnected) return;
    _isConnecting = true;
    notifyListeners();

    final connected = await MqttService.connect(
      serialNumber: serialNumber,
      onDisconnected: () {
        _isConnected = false;
        notifyListeners();
        _scheduleReconnect(serialNumber);
      },
    );
    _isConnected = connected;
    _isConnecting = false;
    notifyListeners();

    if (!connected) _scheduleReconnect(serialNumber);
  }

  void _scheduleReconnect(String serialNumber) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connect(serialNumber: serialNumber);
    });
  }

  void onDisconnected() {
    _isConnected = false;
    notifyListeners();
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    await MqttService.disconnect();
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    super.dispose();
  }
}