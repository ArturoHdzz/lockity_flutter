import 'package:lockity_flutter/models/audit_log_request.dart';
import 'package:lockity_flutter/models/audit_log_response.dart';
import 'package:lockity_flutter/repositories/audit_log_repository.dart';

class AuditLogRepositoryMock implements AuditLogRepository {
  @override
  Future<AuditLogResponse> getAuditLogs(AuditLogRequest request) async {
    // Simular delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Datos mock simples
    final mockResponse = {
      "success": true,
      "message": "Access logs retrieved successfully",
      "data": {
        "items": [
          {
            "id": 1,
            "performed_by": {
              "full_name": "Marco Antonio Chavez",
              "email": "marco@lockity.com",
              "role": "admin"
            },
            "locker": {
              "serial_number": "LOC-001",
              "number_in_the_area": 1,
              "manipulated_compartment": 1,
              "organization_name": "Lockity",
              "area_name": "Pasillo A"
            },
            "target_user": {
              "full_name": "Arturo Hernandez",
              "email": "arturo@test.com",
              "role": "user"
            },
            "description": "Usuario asignado al locker 1"
          },
          {
            "id": 2,
            "performed_by": {
              "full_name": "Ana Rodriguez",
              "email": "ana@lockity.com",
              "role": "manager"
            },
            "locker": {
              "serial_number": "LOC-002",
              "number_in_the_area": 2,
              "manipulated_compartment": 1,
              "organization_name": "Lockity",
              "area_name": "Pasillo B"
            },
            "target_user": {
              "full_name": "Carlos Martinez",
              "email": "carlos@test.com",
              "role": "user"
            },
            "description": "Usuario accedió al locker 2"
          },
          {
            "id": 3,
            "performed_by": {
              "full_name": "Luis Garcia",
              "email": "luis@lockity.com",
              "role": "admin"
            },
            "locker": null,
            "target_user": {
              "full_name": "Maria Silva",
              "email": "maria@test.com",
              "role": "user"
            },
            "description": "Nuevo usuario creado en el sistema"
          }
        ],
        "total": request.page == 1 ? 8 : 3,
        "page": request.page,
        "limit": request.limit,
        "has_next_page": request.page == 1,
        "has_previous_page": false
      }
    };

    return AuditLogResponse.fromJson(mockResponse);
  }
}