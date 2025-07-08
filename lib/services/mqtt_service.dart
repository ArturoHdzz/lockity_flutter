import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:lockity_flutter/core/app_config.dart';

class MqttService {
  static MqttServerClient? _client;
  static String? _currentLocation;
  static int? _currentLockerId;
  static bool _isConnected = false;

  static bool get isConnected => _isConnected;
  static String? get currentLocation => _currentLocation;
  static int? get currentLockerId => _currentLockerId;
  static bool get isSecureConnection => _isConnected && (_client?.secure ?? false);

  static Future<bool> connect({
    required String location,
    required int lockerId,
  }) async {
    try {
      debugPrint('🔌 MQTT: ===== STARTING CONNECTION =====');
      debugPrint('🔌 MQTT: Host: ${AppConfig.mqttBrokerHost}');
      debugPrint('🔌 MQTT: Port: ${AppConfig.mqttBrokerPort}');
      debugPrint('🔌 MQTT: Client ID: ${AppConfig.mqttClientId}');
      debugPrint('🔌 MQTT: Username: ${AppConfig.mqttUsername}');
      // MOSTRAR MÁS CARACTERES DEL PASSWORD PARA DEBUGGING
      debugPrint('🔌 MQTT: Password: ${AppConfig.mqttPassword.length > 20 ? AppConfig.mqttPassword.substring(0, 20) : AppConfig.mqttPassword}...');
      debugPrint('📍 MQTT: Location: $location, Locker ID: $lockerId');
      
      _currentLocation = location;
      _currentLockerId = lockerId;

      // Intentar SSL primero
      bool connected = await _trySSLConnection();
      
      if (!connected) {
        debugPrint('🔄 MQTT: SSL failed, trying insecure connection...');
        connected = await _tryInsecureConnection();
      }

      if (connected) {
        await _subscribeToTopics();
        debugPrint('✅ MQTT: ===== CONNECTION SUCCESSFUL =====');
        debugPrint('✅ MQTT: Connection type: ${isSecureConnection ? "SSL" : "Insecure"}');
      } else {
        debugPrint('❌ MQTT: ===== ALL CONNECTION ATTEMPTS FAILED =====');
      }

      return connected;
    } catch (e, stackTrace) {
      debugPrint('❌ MQTT: ===== CONNECTION ERROR =====');
      debugPrint('❌ MQTT: Error: $e');
      debugPrint('❌ MQTT: Error type: ${e.runtimeType}');
      debugPrint('❌ MQTT: Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<bool> _trySSLConnection() async {
    try {
      debugPrint('🔐 MQTT: ===== ATTEMPTING SSL CONNECTION =====');
      await _cleanupClient();

      _client = MqttServerClient.withPort(
        AppConfig.mqttBrokerHost,
        AppConfig.mqttClientId,
        AppConfig.mqttBrokerPort, // 8883
      );

      final client = _client;
      if (client == null) {
        debugPrint('❌ MQTT: Failed to create SSL client instance');
        return false;
      }

      debugPrint('🔐 MQTT: Setting up SSL configuration...');
      client.secure = true;
      client.keepAlivePeriod = 30;
      client.connectTimeoutPeriod = 15000; // Aumentar timeout
      client.autoReconnect = true;

      await _setupSSL(client);
      _setupCallbacks(client);

      debugPrint('🔐 MQTT: Creating connection message...');
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(AppConfig.mqttClientId)
          .authenticateAs(AppConfig.mqttUsername, AppConfig.mqttPassword)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      client.connectionMessage = connMessage;
      
      debugPrint('🔐 MQTT: Attempting to connect...');
      final result = await client.connect();

      debugPrint('🔐 MQTT: Connection result: ${result?.state}');
      debugPrint('🔐 MQTT: Return code: ${result?.returnCode}');

      if (result?.state == MqttConnectionState.connected) {
        _isConnected = true;
        debugPrint('✅ MQTT: SSL connection established successfully');
        return true;
      } else {
        debugPrint('❌ MQTT: SSL connection failed');
        debugPrint('❌ MQTT: State: ${result?.state}');
        debugPrint('❌ MQTT: Return code: ${result?.returnCode}');
        await _cleanupClient();
        return false;
      }
    } catch (e) {
      debugPrint('❌ MQTT: SSL connection exception: $e');
      debugPrint('❌ MQTT: SSL exception type: ${e.runtimeType}');
      await _cleanupClient();
      return false;
    }
  }

  static Future<bool> _tryInsecureConnection() async {
    try {
      debugPrint('🔓 MQTT: ===== ATTEMPTING INSECURE CONNECTION =====');
      await _cleanupClient();

      _client = MqttServerClient.withPort(
        AppConfig.mqttBrokerHost,
        AppConfig.mqttClientId,
        1883, // Puerto inseguro
      );

      final client = _client;
      if (client == null) {
        debugPrint('❌ MQTT: Failed to create insecure client instance');
        return false;
      }

      debugPrint('🔓 MQTT: Setting up insecure configuration...');
      client.secure = false;
      client.keepAlivePeriod = 30;
      client.connectTimeoutPeriod = 10000;
      client.autoReconnect = true;

      _setupCallbacks(client);

      debugPrint('🔓 MQTT: Creating connection message...');
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(AppConfig.mqttClientId)
          .authenticateAs(AppConfig.mqttUsername, AppConfig.mqttPassword)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      client.connectionMessage = connMessage;
      
      debugPrint('🔓 MQTT: Attempting to connect...');
      final result = await client.connect();

      debugPrint('🔓 MQTT: Connection result: ${result?.state}');
      debugPrint('🔓 MQTT: Return code: ${result?.returnCode}');

      if (result?.state == MqttConnectionState.connected) {
        _isConnected = true;
        debugPrint('✅ MQTT: Insecure connection established successfully');
        return true;
      } else {
        debugPrint('❌ MQTT: Insecure connection failed');
        debugPrint('❌ MQTT: State: ${result?.state}');
        debugPrint('❌ MQTT: Return code: ${result?.returnCode}');
        await _cleanupClient();
        return false;
      }
    } catch (e) {
      debugPrint('❌ MQTT: Insecure connection exception: $e');
      debugPrint('❌ MQTT: Insecure exception type: ${e.runtimeType}');
      await _cleanupClient();
      return false;
    }
  }

  static Future<void> _setupSSL(MqttServerClient client) async {
    try {
      debugPrint('🔒 MQTT: Setting up SSL context...');
      
      // Configuración SSL permisiva para desarrollo
      final context = SecurityContext(withTrustedRoots: false);
      
      // Cargar certificados si existen
      try {
        // Si tienes los archivos de certificados, descomenta esto:
        // final certBytes = await File('assets/config/mosquito.crt').readAsBytes();
        // final keyBytes = await File('assets/config/mosquito.key').readAsBytes();
        // context.useCertificateChainBytes(certBytes);
        // context.usePrivateKeyBytes(keyBytes);
        
        debugPrint('🔒 MQTT: SSL certificates loaded (if any)');
      } catch (e) {
        debugPrint('⚠️ MQTT: SSL certificates not loaded: $e');
      }
      
      client.securityContext = context;
      
      // Permitir certificados auto-firmados para desarrollo
      client.onBadCertificate = (dynamic cert) {
        debugPrint('⚠️ MQTT: Bad certificate callback triggered');
        debugPrint('⚠️ MQTT: Certificate: $cert');
        return true; // Aceptar certificados inválidos en desarrollo
      };
      
      debugPrint('✅ MQTT: SSL context configured');
    } catch (e) {
      debugPrint('❌ MQTT: SSL setup error: $e');
      rethrow;
    }
  }

  static void _setupCallbacks(MqttServerClient client) {
    debugPrint('📞 MQTT: Setting up callbacks...');
    
    client.onConnected = () {
      _isConnected = true;
      debugPrint('🔗 MQTT: ===== CONNECTED CALLBACK =====');
      debugPrint('🔗 MQTT: Client connected successfully');
    };
    
    client.onDisconnected = () {
      _isConnected = false;
      debugPrint('💔 MQTT: ===== DISCONNECTED CALLBACK =====');
      debugPrint('💔 MQTT: Client disconnected');
    };

    client.onSubscribed = (String topic) {
      debugPrint('📡 MQTT: ===== SUBSCRIBED =====');
      debugPrint('📡 MQTT: Successfully subscribed to: $topic');
    };

    client.onSubscribeFail = (String topic) {
      debugPrint('📡 MQTT: ===== SUBSCRIPTION FAILED =====');
      debugPrint('📡 MQTT: Failed to subscribe to: $topic');
    };

    client.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? messages) {
      if (messages == null) return;
      
      debugPrint('📨 MQTT: ===== MESSAGE RECEIVED =====');
      
      for (final message in messages) {
        final topic = message.topic;
        final payload = MqttPublishPayload.bytesToStringAsString(
          (message.payload as MqttPublishMessage).payload.message,
        );
        debugPrint('📍 MQTT: Topic: $topic');
        debugPrint('📄 MQTT: Payload: $payload');
      }
    });
    
    debugPrint('✅ MQTT: Callbacks configured');
  }

  static Future<void> _subscribeToTopics() async {
    final client = _client;
    if (client == null || !_isConnected) {
      debugPrint('❌ MQTT: Cannot subscribe - client not connected');
      return;
    }

    try {
      // Topics basados en la documentación MQTT
      final topics = [
        '$_currentLocation/$_currentLockerId/status',
        '$_currentLocation/$_currentLockerId/response',
        '$_currentLocation/$_currentLockerId/comand/fingerprint', // Respuestas de huella
      ];

      debugPrint('📡 MQTT: ===== SUBSCRIBING TO TOPICS =====');
      for (final topic in topics) {
        debugPrint('📡 MQTT: Subscribing to: $topic');
        client.subscribe(topic, MqttQos.atLeastOnce);
      }
      debugPrint('✅ MQTT: All subscriptions requested');
    } catch (e) {
      debugPrint('❌ MQTT: Subscription error: $e');
    }
  }

  // Comando para abrir compartimento - según documentación MQTT
  static Future<bool> openCompartment({
    required String userId,
    required int compartmentId,
  }) async {
    debugPrint('📤 MQTT: ===== OPENING COMPARTMENT =====');
    debugPrint('👤 MQTT: User ID: $userId');
    debugPrint('📦 MQTT: Compartment ID: $compartmentId');
    
    final client = _client;
    if (!_isConnected || client == null) {
      debugPrint('❌ MQTT: Cannot send command - not connected');
      return false;
    }

    // Topic según documentación: {ubicacion}/{id_locker}/comand/toggle
    final topic = '$_currentLocation/$_currentLockerId/comand/toggle';
    final message = {
      'id_usuario': userId,
      'valor': 1, // Valor fijo según documentación
    };

    debugPrint('📍 MQTT: Publishing to topic: $topic');
    debugPrint('📄 MQTT: Message: $message');
    
    return await _publishMessage(client, topic, message);
  }

  // Comando para activar alarma - según documentación MQTT
  static Future<bool> activateAlarm() async {
    debugPrint('📤 MQTT: ===== ACTIVATING ALARM =====');
    
    final client = _client;
    if (!_isConnected || client == null) {
      debugPrint('❌ MQTT: Cannot send alarm - not connected');
      return false;
    }

    // Topic según documentación: {ubicacion}/{id_locker}/comand/alarm
    final topic = '$_currentLocation/$_currentLockerId/comand/alarm';
    final message = {'value': true}; // Según documentación

    debugPrint('📍 MQTT: Publishing alarm to topic: $topic');
    return await _publishMessage(client, topic, message);
  }

  // Comando para tomar foto - según documentación MQTT
  static Future<bool> takePicture() async {
    debugPrint('📤 MQTT: ===== TAKING PICTURE =====');
    
    final client = _client;
    if (!_isConnected || client == null) {
      debugPrint('❌ MQTT: Cannot send picture command - not connected');
      return false;
    }

    // Topic según documentación: {ubicacion}/{id_locker}/comand/picture
    final topic = '$_currentLocation/$_currentLockerId/comand/picture';
    final message = {'value': true}; // Según documentación

    debugPrint('📍 MQTT: Publishing picture command to topic: $topic');
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
      
      debugPrint('📤 MQTT: Publishing message...');
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      
      debugPrint('✅ MQTT: Message published successfully');
      debugPrint('📍 MQTT: Topic: $topic');
      debugPrint('📄 MQTT: Payload: $payload');
      return true;
    } catch (e) {
      debugPrint('❌ MQTT: Publish error: $e');
      return false;
    }
  }

  static Future<void> _cleanupClient() async {
    try {
      _isConnected = false;
      if (_client != null) {
        debugPrint('🧹 MQTT: Cleaning up existing client...');
        _client?.disconnect();
        _client = null;
      }
    } catch (e) {
      debugPrint('⚠️ MQTT: Cleanup error: $e');
      _client = null;
      _isConnected = false;
    }
  }

  static Future<void> disconnect() async {
    debugPrint('🔌 MQTT: ===== DISCONNECTING =====');
    await _cleanupClient();
    _currentLocation = null;
    _currentLockerId = null;
    debugPrint('✅ MQTT: Disconnected and cleaned up');
  }

  static String get connectionStatus {
    if (!_isConnected) return 'Disconnected';
    final client = _client;
    if (client?.secure == true) return 'Connected (SSL)';
    return 'Connected (Insecure)';
  }
}