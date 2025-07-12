import 'dart:async';
import 'package:flutter/foundation.dart';
import 'mqtt_service.dart';

class MqttConnectionManager extends ChangeNotifier {
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  Future<void> connect({required String location, required int lockerId}) async {
    if (_isConnecting || _isConnected) return;
    _isConnecting = true;
    notifyListeners();

    final connected = await MqttService.connect(
      location: location,
      lockerId: lockerId,
      onDisconnected: () {
        _isConnected = false;
        notifyListeners();
        _scheduleReconnect(location, lockerId);
      },
    );
    _isConnected = connected;
    _isConnecting = false;
    notifyListeners();

    if (!connected) _scheduleReconnect(location, lockerId);
  }

  void _scheduleReconnect(String location, int lockerId) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connect(location: location, lockerId: lockerId);
    });
  }

  void onDisconnected() {
    _isConnected = false;
    notifyListeners();
    // Puedes guardar el último locker/location y reintentar
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