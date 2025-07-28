import 'package:flutter/foundation.dart';
import 'package:lockity_flutter/core/app_config.dart';
import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/models/locker_response.dart';
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

      final updateRequest = UpdateLockerStatusRequest(
        lockerId: lockerId,
        status: LockerStatus.open,
      );

      final response = await _lockerRepository.updateLockerStatus(updateRequest);
      return response;

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
}

class ControlLockerException implements Exception {
  final String message;
  const ControlLockerException(this.message);
  @override
  String toString() => 'ControlLockerException: $message';
}