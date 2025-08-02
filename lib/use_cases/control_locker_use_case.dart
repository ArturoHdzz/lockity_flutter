import 'package:flutter/foundation.dart';
import 'package:lockity_flutter/core/app_config.dart';
import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/models/locker_response.dart';
import 'package:lockity_flutter/models/compartment_status_response.dart';
import 'package:lockity_flutter/repositories/locker_repository.dart';
import 'package:lockity_flutter/services/mqtt_service.dart';
import 'package:lockity_flutter/services/user_service.dart';

class ControlLockerUseCase {
  final LockerRepository _lockerRepository;

  const ControlLockerUseCase(this._lockerRepository);

  Future<LockerOperationResponse> openCompartment({
    required int lockerId,
    required int compartmentId,
    required String topic,
  }) async {
    if (AppConfig.useMockLockers) {
      await Future.delayed(const Duration(seconds: 1));
      return const LockerOperationResponse(
        success: true,
        message: 'Compartment opened successfully',
      );
    }

    try {
      final userId = await UserService.getCurrentUserId();
      if (userId == null) {
        throw Exception('Unable to authenticate user');
      }

      if (!MqttService.isConnected) {
        final serialNumber = topic.split('/').first;
        await MqttService.connect(serialNumber: serialNumber);
      }

      if (MqttService.isConnected) {
        await MqttService.openCompartment(
          topic: topic,
          userId: userId,
          compartmentId: compartmentId,
        );
      }

      return const LockerOperationResponse(
        success: true,
        message: 'Compartment opened successfully',
      );

    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<LockerOperationResponse> activateAlarm({
    required int lockerId,
    required String topic,
    String location = 'floor1',
  }) async {
    if (AppConfig.useMockLockers) {
      await Future.delayed(const Duration(seconds: 1));
      return const LockerOperationResponse(
        success: true,
        message: 'Alarm activated successfully',
      );
    }

    try {
      if (!MqttService.isConnected) {
        final serialNumber = topic.split('/').first;
        await MqttService.connect(serialNumber: serialNumber);
      }

      if (MqttService.isConnected) {
        await MqttService.activateAlarm(topic: topic);
      }

      return const LockerOperationResponse(
        success: true,
        message: 'Alarm activated successfully',
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<LockerOperationResponse> takePicture({
    required int lockerId,
    required String topic,
    String location = 'floor1',
  }) async {
    if (AppConfig.useMockLockers) {
      await Future.delayed(const Duration(seconds: 2));
      return const LockerOperationResponse(
        success: true,
        message: 'Picture taken successfully',
      );
    }

    try {
      if (!MqttService.isConnected) {
        final serialNumber = topic.split('/').first;
        await MqttService.connect(serialNumber: serialNumber);
      }

      if (MqttService.isConnected) {
        await MqttService.takePicture(topic: topic);
      }

      return const LockerOperationResponse(
        success: true,
        message: 'Picture taken successfully',
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<CompartmentStatusResponse> getCompartmentStatus({
    required String serialNumber,
    required int compartmentNumber,
  }) async {
    try {
      return await _lockerRepository.getCompartmentStatus(
        serialNumber, 
        compartmentNumber
      );
    } catch (e) {
      throw Exception('Failed to get compartment status: ${e.toString()}');
    }
  }

  Future<LockerOperationResponse> toggleCompartmentStatus({
    required int lockerId,
    required String serialNumber,
    required int compartmentNumber,
    required String topic,
  }) async {
    try {
      final statusResponse = await getCompartmentStatus(
        serialNumber: serialNumber,
        compartmentNumber: compartmentNumber,
      );

      print('🔍 Estado actual del compartimento: ${statusResponse.message}');
      print('📡 Respuesta completa del endpoint: ${statusResponse}');

      final mqttValue = statusResponse.mqttValue;
      final action = statusResponse.isClosed ? 'opening' : 'closing';
      
      print('🔄 Acción a realizar: $action (valor MQTT: $mqttValue)');

      final userId = await UserService.getCurrentUserId();
      if (userId == null) {
        throw Exception('Unable to authenticate user');
      }

      if (!AppConfig.useMockLockers) {
        if (!MqttService.isConnected) {
          await MqttService.connect(serialNumber: serialNumber);
        }

        if (MqttService.isConnected) {
          await _publishToggleMessage(
            topic: topic,
            userId: userId,
            compartmentNumber: compartmentNumber,
            value: mqttValue,
          );
        }
      }

      return LockerOperationResponse(
        success: true,
        message: 'Compartment $action successfully',
      );

    } catch (e) {
      throw Exception('Failed to toggle compartment: ${e.toString()}');
    }
  }

  Future<void> _publishToggleMessage({
    required String topic,
    required String userId,
    required int compartmentNumber,
    required int value,
  }) async {
    final message = {
      'id_usuario': userId,
      'id_drawer': compartmentNumber,
      'valor': value,
      'source': 'mobile',
    };

    print('📤 Publicando en MQTT - Topic: $topic');
    print('📤 Payload: $message');

    await MqttService.publishMessage(topic, message);
  }
}

class ControlLockerException implements Exception {
  final String message;
  const ControlLockerException(this.message);
  @override
  String toString() => 'ControlLockerException: $message';
}