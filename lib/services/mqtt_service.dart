import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:lockity_flutter/core/app_config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MqttService {
  static MqttServerClient? _client;
  static String? _currentSerialNumber;
  static bool _isConnected = false;
  static bool _isDisposing = false;
  static final Map<String, void Function(String payload)> _subscriptions = {};
  static int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  static bool get isConnected => _isConnected && !_isDisposing;
  static String? get currentSerialNumber => _currentSerialNumber;

  static Future<bool> _checkNetworkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      final result = await InternetAddress.lookup(AppConfig.mqttBrokerHost);
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (e) {
      debugPrint('MQTT: Error verificando conectividad: $e');
    }
    return false;
  }

  static Future<bool> connect({
    required String serialNumber,
    void Function()? onDisconnected,
  }) async {
    if (_isConnected && _currentSerialNumber == serialNumber && !_isDisposing) {
      return true;
    }

    if (!await _checkNetworkConnectivity()) {
      return false;
    }

    if (_isConnected || _client != null) {
      await disconnect();
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    try {
      _currentSerialNumber = serialNumber;
      _isDisposing = false;
      _reconnectAttempts = 0;
      
      bool connected = await _trySecureConnection(onDisconnected: onDisconnected);
      if (!connected) {
        connected = await _tryInsecureConnection(onDisconnected: onDisconnected);
      }
      
      return connected;
    } catch (e) {
      debugPrint('MQTT: Error en connect: $e');
      await _cleanupClient();
      return false;
    }
  }

  static Future<bool> _trySecureConnection({void Function()? onDisconnected}) async {
    try {
      _client = MqttServerClient.withPort(
        AppConfig.mqttBrokerHost,
        '${AppConfig.mqttClientId}_$_currentSerialNumber',
        AppConfig.mqttBrokerPort,
      );
      
      return await _configureAndConnect(useSSL: true, onDisconnected: onDisconnected);
    } catch (e) {
      debugPrint('MQTT: Error en conexión segura: $e');
      await _cleanupClient();
      return false;
    }
  }

  static Future<bool> _tryInsecureConnection({void Function()? onDisconnected}) async {
    try {
      _client = MqttServerClient.withPort(
        AppConfig.mqttBrokerHost,
        '${AppConfig.mqttClientId}_$_currentSerialNumber',
        1883,
      );
      
      return await _configureAndConnect(useSSL: false, onDisconnected: onDisconnected);
    } catch (e) {
      debugPrint('MQTT: Error en conexión sin SSL: $e');
      await _cleanupClient();
      return false;
    }
  }

  static Future<bool> _configureAndConnect({
    required bool useSSL,
    void Function()? onDisconnected,
  }) async {
    final client = _client!;
    
    client.logging(on: kDebugMode);
    client.keepAlivePeriod = 30;
    client.autoReconnect = false;
    client.connectTimeoutPeriod = 15000;
    
    client.onConnected = onConnected;
    client.onDisconnected = () {
      if (!_isDisposing) {
        _handleDisconnection(onDisconnected);
      }
    };
    client.onSubscribed = onSubscribed;
    client.onSubscribeFail = onSubscribeFail;
    client.onUnsubscribed = onUnsubscribed;
    client.pongCallback = pong;

    if (useSSL) {
      client.secure = true;
      client.securityContext = SecurityContext.defaultContext;
      
      client.onBadCertificate = (Object cert) {
        if (kDebugMode) {
          return true;
        }
        
        try {
          final x509Cert = cert as X509Certificate;
          bool isExpectedCert = x509Cert.subject.contains('MyMosquittoCA') &&
              x509Cert.issuer.contains('MyMosquittoCA') &&
              AppConfig.mqttBrokerHost == '64.23.237.187';
          return isExpectedCert;
        } catch (e) {
          debugPrint('MQTT: Error validando certificado: $e');
          return false;
        }
      };
    } else {
      client.secure = false;
    }

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('${AppConfig.mqttClientId}_$_currentSerialNumber')
        .authenticateAs(AppConfig.mqttUsername, AppConfig.mqttPassword)
        .keepAliveFor(30)
        .withWillTopic('$_currentSerialNumber/status')
        .withWillMessage('offline')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    
    client.connectionMessage = connMessage;

    try {
      await client.connect();
      
      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        _isConnected = true;
        _reconnectAttempts = 0;
        
        _setupMessageListener(client);
        return true;
      } else {
        await _cleanupClient();
        return false;
      }
    } catch (e) {
      debugPrint('MQTT: Error conectando: $e');
      await _cleanupClient();
      return false;
    }
  }

  static void _setupMessageListener(MqttServerClient client) {
    client.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? messages) {
      if (messages == null || messages.isEmpty || _isDisposing) return;
      
      for (final message in messages) {
        try {
          final MqttPublishMessage recMess = message.payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          _subscriptions[message.topic]?.call(payload);
        } catch (e) {
          debugPrint('MQTT: Error procesando mensaje: $e');
        }
      }
    });
  }

  static void _handleDisconnection(void Function()? onDisconnected) {
    _isConnected = false;
    
    if (_reconnectAttempts < _maxReconnectAttempts && !_isDisposing) {
      _reconnectAttempts++;
      
      Future.delayed(Duration(seconds: _reconnectAttempts * 2), () async {
        if (!_isDisposing && _currentSerialNumber != null) {
          await connect(serialNumber: _currentSerialNumber!, onDisconnected: onDisconnected);
        }
      });
    } else {
      onDisconnected?.call();
    }
  }

  static Future<void> _cleanupClient() async {
    try {
      _isDisposing = true;
      _isConnected = false;
      
      if (_client != null) {
        try {
          _client?.disconnect();
        } catch (e) {
          debugPrint('MQTT: Error desconectando: $e');
        }
        _client = null;
      }
      
      _subscriptions.clear();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('MQTT: Error en cleanup: $e');
    } finally {
      _isDisposing = false;
    }
  }

  static void onConnected() {
    if (!_isDisposing && _client != null) {
      _isConnected = true;
    }
  }

  static void onDisconnected() {
    if (_isConnected && !_isDisposing) {
      _isConnected = false;
    }
  }

  static void onSubscribed(String topic) {
    debugPrint('MQTT: Suscrito a $topic');
  }
  
  static void onSubscribeFail(String topic) {
    debugPrint('MQTT: Error suscribiendo a $topic');
  }
  
  static void onUnsubscribed(String? topic) {
    debugPrint('MQTT: Desuscrito de $topic');
  }
  
  static void pong() {
    debugPrint('MQTT: Pong recibido');
  }

  static void subscribe(String topic, void Function(String payload) onMessage) {
    if (_client == null || !_isConnected || _isDisposing) {
      return;
    }
    
    try {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      _subscriptions[topic] = onMessage;
    } catch (e) {
      debugPrint('MQTT: Error suscribiendo a $topic: $e');
    }
  }

  static void unsubscribe(String topic) {
    if (_client == null || _isDisposing) {
      return;
    }
    
    try {
      _client?.unsubscribe(topic);
      _subscriptions.remove(topic);
    } catch (e) {
      debugPrint('MQTT: Error desuscribiendo de $topic: $e');
      _subscriptions.remove(topic);
    }
  }

  static Future<void> publishMessage(String topic, Map<String, dynamic> message) async {
    if (_client == null || !_isConnected || _isDisposing) {
      return;
    }
    
    try {
      final payload = json.encode(message);
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    } catch (e) {
      debugPrint('MQTT: Error publicando mensaje en $topic: $e');
    }
  }

  static Future<void> disconnect() async {
    await _cleanupClient();
    _currentSerialNumber = null;
    _reconnectAttempts = 0;
  }

  static Future<bool> openCompartment({
    required String topic,
    required String userId,
    required int compartmentId,
  }) async {
    final client = _client;
    if (!_isConnected || client == null || _isDisposing) {
      return false;
    }
    
    final message = {
      'id_usuario': userId,
      'id_drawer': compartmentId,
      'valor': 1,
      'source': 'mobile',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    return await _publishMessage(client, topic, message);
  }

  static Future<bool> activateAlarm({required String topic}) async {
    final client = _client;
    if (!_isConnected || client == null || _isDisposing) {
      return false;
    }
    
    final message = {
      'value': true,
      'source': 'mobile',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    return await _publishMessage(client, topic, message);
  }

  static Future<bool> takePicture({required String topic}) async {
    final client = _client;
    if (!_isConnected || client == null || _isDisposing) {
      return false;
    }
    
    final message = {
      'value': true,
      'source': 'mobile',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    return await _publishMessage(client, topic, message);
  }

  static Future<bool> _publishMessage(
    MqttServerClient client,
    String topic,
    Map<String, dynamic> message,
  ) async {
    try {
      final payload = json.encode(message);
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      return true;
    } catch (e) {
      debugPrint('MQTT: Error enviando comando a $topic: $e');
      return false;
    }
  }

  static Map<String, dynamic> getConnectionStatus() {
    return {
      'isConnected': _isConnected,
      'isDisposing': _isDisposing,
      'currentSerialNumber': _currentSerialNumber,
      'reconnectAttempts': _reconnectAttempts,
      'clientExists': _client != null,
      'connectionState': _client?.connectionStatus?.state.toString(),
      'subscriptions': _subscriptions.keys.toList(),
    };
  }
}