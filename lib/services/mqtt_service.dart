import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:lockity_flutter/core/app_config.dart';

class MqttService {
  static MqttServerClient? _client;
  static String? _currentSerialNumber;
  static bool _isConnected = false;
  static bool _isDisposing = false;
  static final Map<String, void Function(String payload)> _subscriptions = {};

  static bool get isConnected => _isConnected && !_isDisposing;
  static String? get currentSerialNumber => _currentSerialNumber;

  static Future<bool> connect({
    required String serialNumber,
    void Function()? onDisconnected,
  }) async {
    if (_isConnected && _currentSerialNumber == serialNumber && !_isDisposing) {
      return true;
    }
    if (_isConnected || _client != null) {
      await disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    try {
      _currentSerialNumber = serialNumber;
      _isDisposing = false;
      bool connected = await _tryConnection(onDisconnected: onDisconnected);
      return connected;
    } catch (e) {
      await _cleanupClient();
      return false;
    }
  }

  static Future<bool> _tryConnection({void Function()? onDisconnected}) async {
    try {
      _client = MqttServerClient.withPort(
        AppConfig.mqttBrokerHost,
        '${AppConfig.mqttClientId}_$_currentSerialNumber',
        AppConfig.mqttBrokerPort,
      );
      final client = _client!;
      client.logging(on: kDebugMode);
      client.keepAlivePeriod = 60;
      client.autoReconnect = true;
      client.onConnected = onConnected;
      client.onDisconnected = () {
        if (!_isDisposing) {
          onDisconnected?.call();
        }
      };
      client.onSubscribed = onSubscribed;
      client.onSubscribeFail = onSubscribeFail;
      client.onUnsubscribed = onUnsubscribed;
      client.pongCallback = pong;
      client.secure = true;
      client.securityContext = SecurityContext.defaultContext;
      client.onBadCertificate = (Object cert) {
        if (kDebugMode) {
          try {
            final x509Cert = cert as X509Certificate;
            bool isExpectedCert = x509Cert.subject.contains('MyMosquittoCA') &&
                x509Cert.issuer.contains('MyMosquittoCA') &&
                AppConfig.mqttBrokerHost == '64.23.237.187';
            if (isExpectedCert) {
              return true;
            }
          } catch (e) {}
        }
        return false;
      };
      final connMessage = MqttConnectMessage()
          .withClientIdentifier('${AppConfig.mqttClientId}_$_currentSerialNumber')
          .authenticateAs(AppConfig.mqttUsername, AppConfig.mqttPassword)
          .keepAliveFor(60)
          .withWillTopic('$_currentSerialNumber/status')
          .withWillMessage('offline')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      client.connectionMessage = connMessage;
      await client.connect();
      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        _isConnected = true;
        client.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? messages) {
          if (messages == null || messages.isEmpty || _isDisposing) return;
          for (final message in messages) {
            try {
              final MqttPublishMessage recMess = message.payload as MqttPublishMessage;
              final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
              _subscriptions[message.topic]?.call(payload);
            } catch (e) {}
          }
        });
        return true;
      } else {
        await _cleanupClient();
        return false;
      }
    } catch (e) {
      await _cleanupClient();
      return false;
    }
  }

  static Future<void> _cleanupClient() async {
    try {
      _isDisposing = true;
      _isConnected = false;
      if (_client != null) {
        _client?.disconnect();
        _client = null;
      }
      _subscriptions.clear();
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
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
    if (_isConnected && !_isDisposing && _client != null) {
      _isConnected = false;
    }
  }

  static void onSubscribed(String topic) {}
  static void onSubscribeFail(String topic) {}
  static void onUnsubscribed(String? topic) {}
  static void pong() {}

  static void subscribe(String topic, void Function(String payload) onMessage) {
    if (_client == null || !_isConnected || _isDisposing) {
      return;
    }
    try {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      _subscriptions[topic] = onMessage;
    } catch (e) {}
  }

  static void unsubscribe(String topic) {
    if (_client == null || !_isConnected || _isDisposing) {
      return;
    }
    try {
      _client?.unsubscribe(topic);
      _subscriptions.remove(topic);
    } catch (e) {
      _subscriptions.remove(topic);
    }
  }

  static Future<void> publishMessage(String topic, Map<String, dynamic> message) async {
    if (_client == null || !_isConnected || _isDisposing) {
      return;
    }
    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(json.encode(message));
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    } catch (e) {}
  }

  static Future<void> disconnect() async {
    await _cleanupClient();
    _currentSerialNumber = null;
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
      return false;
    }
  }
}