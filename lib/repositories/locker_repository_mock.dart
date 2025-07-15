import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/models/locker_response.dart';
import 'package:lockity_flutter/models/locker_config_response.dart';
import 'package:lockity_flutter/repositories/locker_repository.dart';

class LockerRepositoryMock implements LockerRepository {
  static const Duration _networkDelay = Duration(milliseconds: 800);

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
}