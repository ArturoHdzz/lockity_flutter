import 'package:lockity_flutter/models/audit_log_request.dart';
import 'package:lockity_flutter/models/audit_log_response.dart';

abstract class AuditLogRepository {
  Future<AuditLogResponse> getAuditLogs(AuditLogRequest request);
}