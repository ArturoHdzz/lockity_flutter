import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/models/locker_response.dart';
import 'package:lockity_flutter/models/locker_config_response.dart';
import 'package:lockity_flutter/models/compartment_status_response.dart';
import 'package:lockity_flutter/repositories/locker_repository.dart';

class LockerRepositoryMock implements LockerRepository {
  static const Duration _networkDelay = Duration(milliseconds: 800);
  
  static final Map<String, String> _compartmentStates = {
    'SN-2025-0745-AX93-PLQ7-1': 'closed',
    'SN-2025-0745-AX93-PLQ7-2': 'open',
    'SN-2025-0745-AX93-PLQ7-3': 'closed',
  };

  static final List<Map<String, dynamic>> _mockLockers = [
    {
      "id": 1,
      "organization_id": 1,
      "area_id": 1,
      "locker_number": 1,
      "organization_name": "Lockity HQ",
      "area_name": "Main Office - Floor 1",
      "status": "closed"
    },
    {
      "id": 2,
      "organization_id": 1,
      "area_id": 1,
      "locker_number": 2,
      "organization_name": "Lockity HQ",
      "area_name": "Main Office - Floor 1",
      "status": "closed"
    },
    {
      "id": 3,
      "organization_id": 1,
      "area_id": 2,
      "locker_number": 3,
      "organization_name": "Lockity HQ",
      "area_name": "Secure Zone - Floor 2",
      "status": "maintenance"
    },
  ];

  @override
  Future<LockerListResponse> getLockers(LockerListRequest request) async {
    await Future.delayed(_networkDelay);

    final mockResponse = {
      "success": true,
      "message": "Lockers retrieved successfully",
      "data": {
        "items": _mockLockers,
        "total": _mockLockers.length,
        "page": request.page,
        "limit": request.limit,
        "has_next_page": false,
        "has_previous_page": false
      }
    };

    return LockerListResponse.fromJson(mockResponse);
  }

  @override
  Future<LockerOperationResponse> updateLockerStatus(UpdateLockerStatusRequest request) async {
    await Future.delayed(_networkDelay);

    final mockResponse = {
      "success": true,
      "message": "Locker status updated successfully",
    };

    return LockerOperationResponse.fromJson(mockResponse);
  }

  @override
  Future<LockerConfigResponse> getLockerConfig(String serialNumber) async {
    await Future.delayed(_networkDelay);
    return LockerConfigResponse(
      lockerId: '1',
      topics: {
        'toggle': 'mock/toggle',
        'alarm': 'mock/alarm',
        'picture': 'mock/picture',
      },
    );
  }

  @override
  Future<CompartmentStatusResponse> getCompartmentStatus(
    String serialNumber, 
    int compartmentNumber
  ) async {
    await Future.delayed(_networkDelay);

    final key = '$serialNumber-$compartmentNumber';
    
    final currentState = _compartmentStates[key] ?? 'closed';

    final mockResponse = {
      "success": true,
      "message": currentState,
      "data": null
    };

    print('Mock: Estado actual para $key: $currentState');
    
    return CompartmentStatusResponse.fromJson(mockResponse);
  }

  static void simulateToggle(String serialNumber, int compartmentNumber) {
    final key = '$serialNumber-$compartmentNumber';
    final currentState = _compartmentStates[key] ?? 'closed';
    final newState = currentState == 'closed' ? 'open' : 'closed';
    _compartmentStates[key] = newState;
    
    print('Mock: Estado cambiado para $key: $currentState -> $newState');
  }
}