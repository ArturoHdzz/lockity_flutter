import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/models/locker_response.dart';
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

  static final Map<int, List<Map<String, dynamic>>> _mockCompartments = {
    1: [
      {
        "id": 1,
        "compartment_number": 1,
        "status": "closed",
        "users": [
          {
            "id": 1,
            "name": "Jesus Arturo",
            "last_name": "Hernandez",
            "second_last_name": "Cristan",
            "email": "arturo@lockity.com",
            "role": "admin"
          }
        ]
      },
      {
        "id": 2,
        "compartment_number": 2,
        "status": "closed",
        "users": [
          {
            "id": 1,
            "name": "Jesus Arturo",
            "last_name": "Hernandez",
            "second_last_name": "Cristan",
            "email": "arturo@lockity.com",
            "role": "admin"
          },
          {
            "id": 2,
            "name": "Marco Antonio",
            "last_name": "Chavez",
            "second_last_name": "Baltierrez",
            "email": "marco@lockity.com",
            "role": "user"
          }
        ]
      }
    ],
    2: [
      {
        "id": 3,
        "compartment_number": 1,
        "status": "open",
        "users": [
          {
            "id": 2,
            "name": "Marco Antonio",
            "last_name": "Chavez",
            "second_last_name": "Baltierrez",
            "email": "marco@lockity.com",
            "role": "user"
          }
        ]
      }
    ],
    3: [
      {
        "id": 4,
        "compartment_number": 1,
        "status": "error",
        "users": []
      }
    ],
  };

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
  Future<CompartmentListResponse> getCompartments(int lockerId) async {
    await Future.delayed(_networkDelay);

    final compartments = _mockCompartments[lockerId] ?? [];

    final mockResponse = {
      "success": true,
      "message": "Compartments retrieved successfully",
      "data": {
        "items": compartments,
        "total": compartments.length,
        "page": 1,
        "limit": 10,
        "has_next_page": false,
        "has_previous_page": false
      }
    };

    return CompartmentListResponse.fromJson(mockResponse);
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
}