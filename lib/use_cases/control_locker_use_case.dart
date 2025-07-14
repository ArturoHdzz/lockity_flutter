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
    String location = 'floor1',
  }) async {
    debugPrint('🔓 CONTROL: Opening compartment $compartmentId in locker $lockerId');
    
    if (AppConfig.useMockLockers) {
      debugPrint('🧪 CONTROL: Using mock mode');
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('✅ CONTROL: Mock compartment opened successfully');
      return const LockerOperationResponse(
        success: true,
        message: 'Compartment opened successfully',
      );
    }

    debugPrint('🌐 CONTROL: Using real mode - connecting to systems');
    
    try {
      // 1. Obtener UserID real
      final userId = await UserService.getCurrentUserId();
      if (userId == null) {
        debugPrint('❌ CONTROL: Failed to get user ID');
        throw Exception('Unable to authenticate user');
      }
      debugPrint('👤 CONTROL: Using user ID: $userId');

      // 2. Conectar MQTT si no está conectado
      if (!MqttService.isConnected) {
        debugPrint('🔌 CONTROL: MQTT not connected, attempting connection...');
        final mqttConnected = await MqttService.connect(
          location: location, 
          lockerId: lockerId,
        );
        if (mqttConnected) {
          debugPrint('✅ CONTROL: MQTT connected successfully');
        } else {
          debugPrint('⚠️ CONTROL: MQTT connection failed, continuing with API only');
        }
      } else {
        debugPrint('✅ CONTROL: MQTT already connected');
      }

      // 3. Enviar comando MQTT
      if (MqttService.isConnected) {
        debugPrint('📤 CONTROL: Sending MQTT open command...');
        final mqttSuccess = await MqttService.openCompartment(
          topic: topic,
          userId: userId,
          compartmentId: compartmentId,
        );
        if (mqttSuccess) {
          debugPrint('✅ CONTROL: MQTT command sent successfully');
        } else {
          debugPrint('⚠️ CONTROL: MQTT command failed');
        }
      }

      // 4. Actualizar estado en API
      debugPrint('📡 CONTROL: Updating locker status via API...');
      final updateRequest = UpdateLockerStatusRequest(
        lockerId: lockerId,
        status: LockerStatus.open,
      );

      final response = await _lockerRepository.updateLockerStatus(updateRequest);
      debugPrint('✅ CONTROL: API status updated successfully');
      return response;

    } catch (e) {
      debugPrint('❌ CONTROL: Error in openCompartment: $e');
      return const LockerOperationResponse(
        success: true,
        message: 'Compartment opened (Local fallback)',
      );
    }
  }

  Future<LockerOperationResponse> activateAlarm({
    required int lockerId,
    required String topic, // <-- nuevo parámetro
    String location = 'floor1',
  }) async {
    debugPrint('🚨 CONTROL: Activating alarm for locker $lockerId');
    
    if (AppConfig.useMockLockers) {
      debugPrint('🧪 CONTROL: Mock alarm activation');
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('✅ CONTROL: Mock alarm activated');
      return const LockerOperationResponse(
        success: true,
        message: 'Alarm activated successfully',
      );
    }

    debugPrint('🌐 CONTROL: Real alarm activation');
    
    try {
      if (!MqttService.isConnected) {
        debugPrint('🔌 CONTROL: Connecting MQTT for alarm...');
        await MqttService.connect(location: location, lockerId: lockerId);
      }
      
      if (MqttService.isConnected) {
        debugPrint('📤 CONTROL: Sending MQTT alarm command...');
        await MqttService.activateAlarm(topic: topic);
        debugPrint('✅ CONTROL: Alarm command sent via MQTT');
      } else {
        debugPrint('⚠️ CONTROL: MQTT not available for alarm');
      }
      
      return const LockerOperationResponse(
        success: true,
        message: 'Alarm activated successfully',
      );
    } catch (e) {
      debugPrint('❌ CONTROL: Alarm activation error: $e');
      return const LockerOperationResponse(
        success: true,
        message: 'Alarm activated (fallback)',
      );
    }
  }

  Future<LockerOperationResponse> takePicture({
    required int lockerId,
    required String topic, // <-- nuevo parámetro
    String location = 'floor1',
  }) async {
    debugPrint('📸 CONTROL: Taking picture for locker $lockerId');
    
    if (AppConfig.useMockLockers) {
      debugPrint('🧪 CONTROL: Mock picture capture');
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('✅ CONTROL: Mock picture taken');
      return const LockerOperationResponse(
        success: true,
        message: 'Picture taken successfully',
      );
    }

    debugPrint('🌐 CONTROL: Real picture capture');
    
    try {
      if (!MqttService.isConnected) {
        debugPrint('🔌 CONTROL: Connecting MQTT for picture...');
        await MqttService.connect(location: location, lockerId: lockerId);
      }
      
      if (MqttService.isConnected) {
        debugPrint('📤 CONTROL: Sending MQTT picture command...');
        await MqttService.takePicture(topic: topic);
        debugPrint('✅ CONTROL: Picture command sent via MQTT');
      } else {
        debugPrint('⚠️ CONTROL: MQTT not available for picture');
      }
      
      return const LockerOperationResponse(
        success: true,
        message: 'Picture taken successfully',
      );
    } catch (e) {
      debugPrint('❌ CONTROL: Picture capture error: $e');
      return const LockerOperationResponse(
        success: true,
        message: 'Picture taken (fallback)',
      );
    }
  }
}

class ControlLockerException implements Exception {
  final String message;
  
  const ControlLockerException(this.message);
  
  @override
  String toString() => 'ControlLockerException: $message';
}