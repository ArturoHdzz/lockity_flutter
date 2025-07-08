import 'package:lockity_flutter/models/audit_log_request.dart';
import 'package:lockity_flutter/models/audit_log_response.dart';
import 'package:lockity_flutter/repositories/audit_log_repository.dart';

class GetAuditLogsUseCase {
  final AuditLogRepository _auditLogRepository;

  const GetAuditLogsUseCase(this._auditLogRepository);

  Future<AuditLogResponse> execute(AuditLogRequest request) async {
    try {
      return await _auditLogRepository.getAuditLogs(request);
    } catch (e) {
      rethrow;
    }
  }
}