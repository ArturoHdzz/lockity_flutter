import 'dart:async';
import 'dart:convert';
import 'package:lockity_flutter/services/mqtt_service.dart';
import 'package:lockity_flutter/models/fingerprint_message.dart';

class RegisterFingerprintUseCase {
  StreamSubscription<String>? _fingerprintSubscription;
  Timer? _timeoutTimer;
  String? _currentTopic;
  bool _isActive = false;

  Future<void> start({
    required String serialNumber,
    required int userId,
    required void Function(FingerprintMessage step) onStep,
    required void Function(String error) onError,
  }) async {
    final topic = '$serialNumber/command/fingerprint';
    await _cleanup();
    _currentTopic = topic;
    _isActive = true;

    try {
      if (!MqttService.isConnected || MqttService.currentSerialNumber != serialNumber) {
        final connected = await MqttService.connect(
          serialNumber: serialNumber,
          onDisconnected: () {
            if (_isActive) {
              _handleError(onError, 'Se perdió la conexión con el dispositivo');
            }
          },
        );
        if (!connected) {
          _handleError(onError, 'No se pudo conectar al servidor de huellas. Verifica tu conexión.');
          return;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!_isActive) return;

      MqttService.subscribe(topic, (String payload) {
        if (!_isActive) return;
        try {
          final data = json.decode(payload) as Map<String, dynamic>;
          if (!data.containsKey('stage')) return;
          final step = FingerprintMessage.fromJson(data);
          _timeoutTimer?.cancel();
          if (_isActive) onStep(step);
        } catch (e) {
          if (_isActive) {
            _handleError(onError, 'Error procesando respuesta del dispositivo');
          }
        }
      });

      await Future.delayed(const Duration(milliseconds: 300));
      if (!_isActive) return;

      final message = {
        'config': 1,
        'user_id': userId,
        'source': 'mobile',
      };
      await MqttService.publishMessage(topic, message);

      _timeoutTimer = Timer(const Duration(seconds: 45), () {
        if (_isActive) {
          _handleError(onError, 'El dispositivo no respondió. Verifica que esté encendido y conectado.');
        }
      });
    } catch (e) {
      String errorMessage = _getErrorMessage(e.toString());
      _handleError(onError, errorMessage);
    }
  }

  void _handleError(void Function(String error) onError, String message) {
    if (_isActive) {
      _cleanup();
      onError(message);
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('certificate') || error.contains('SSL') || error.contains('TLS')) {
      return 'Error de certificado SSL. Verifica la configuración de seguridad.';
    } else if (error.contains('permission') || error.contains('authorization')) {
      return 'Error de permisos. Verifica que tienes acceso al dispositivo.';
    } else if (error.contains('timeout') || error.contains('connection')) {
      return 'Tiempo de espera agotado. Verifica que el dispositivo esté conectado.';
    } else if (error.contains('authentication') || error.contains('credentials')) {
      return 'Error de autenticación. Verifica tus credenciales.';
    } else if (error.contains('network') || error.contains('socket')) {
      return 'Error de red. Verifica tu conexión a internet.';
    } else if (error.contains('disposed') || error.contains('MqttConnectionManager')) {
      return 'Error de conexión. Reintenta la operación.';
    } else {
      return 'Error iniciando registro de huella: $error';
    }
  }

  Future<void> cancel(String serialNumber) async {
    await _cleanup();
  }

  Future<void> _cleanup() async {
    _isActive = false;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    if (_currentTopic != null) {
      try {
        MqttService.unsubscribe(_currentTopic!);
      } catch (_) {}
      _currentTopic = null;
    }
    _fingerprintSubscription?.cancel();
    _fingerprintSubscription = null;
  }

  Future<void> dispose() async {
    await _cleanup();
  }
}