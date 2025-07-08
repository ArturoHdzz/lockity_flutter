import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lockity_flutter/core/app_config.dart';
import 'package:lockity_flutter/models/audit_log_request.dart';
import 'package:lockity_flutter/models/audit_log_response.dart';
import 'package:lockity_flutter/repositories/audit_log_repository.dart';
import 'package:lockity_flutter/services/oauth_service.dart';

class AuditLogRepositoryImpl implements AuditLogRepository {
  final http.Client _httpClient;

  AuditLogRepositoryImpl({http.Client? httpClient}) 
    : _httpClient = httpClient ?? http.Client();

  @override
  Future<AuditLogResponse> getAuditLogs(AuditLogRequest request) async {
    try {
      final token = await OAuthService.getStoredToken();
      if (token == null) {
        throw const AuditLogRepositoryException._session('Authentication required');
      }

      final uri = Uri.parse(AppConfig.auditLogsUrl).replace(
        queryParameters: request.toQueryParameters(),
      );

      final response = await _httpClient.get(
        uri,
        headers: {
          ...token.authHeaders,
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: AppConfig.httpTimeout));

      return _handleResponse(response);
    } on AuditLogRepositoryException {
      rethrow;
    } catch (e) {
      throw AuditLogRepositoryException._network(
        'Please check your internet connection and try again.',
      );
    }
  }

  AuditLogResponse _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 401:
        throw const AuditLogRepositoryException._session(
          'Your session has expired. Please sign in again.'
        );
      case 403:
        throw const AuditLogRepositoryException._permission(
          'You don\'t have permission to view audit logs.'
        );
      case 500:
        throw const AuditLogRepositoryException._server(
          'Server error occurred. Please try again later.'
        );
      case 200:
        return _parseSuccessResponse(response);
      default:
        throw AuditLogRepositoryException._server(
          'Unable to load audit logs. Please try again later.'
        );
    }
  }

  AuditLogResponse _parseSuccessResponse(http.Response response) {
    final responseData = _decodeResponse(response);
    
    if (responseData['success'] != true) {
      throw AuditLogRepositoryException._server(
        responseData['message'] ?? 'Failed to load audit logs.'
      );
    }

    try {
      return AuditLogResponse.fromJson(responseData);
    } catch (e) {
      throw const AuditLogRepositoryException._format(
        'Unable to process audit logs data. Please try again.'
      );
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw const AuditLogRepositoryException._format(
        'Server response is invalid. Please try again.'
      );
    }
  }

  void dispose() => _httpClient.close();
}

class AuditLogRepositoryException implements Exception {
  final String message;
  final AuditLogRepositoryErrorType type;
  
  const AuditLogRepositoryException._(this.message, this.type);
  
  const AuditLogRepositoryException._network(String message) 
    : this._(message, AuditLogRepositoryErrorType.network);
    
  const AuditLogRepositoryException._session(String message) 
    : this._(message, AuditLogRepositoryErrorType.session);
    
  const AuditLogRepositoryException._permission(String message) 
    : this._(message, AuditLogRepositoryErrorType.permission);
    
  const AuditLogRepositoryException._server(String message) 
    : this._(message, AuditLogRepositoryErrorType.server);
    
  const AuditLogRepositoryException._format(String message) 
    : this._(message, AuditLogRepositoryErrorType.format);
  
  bool get isRetryable => type == AuditLogRepositoryErrorType.network || 
                         type == AuditLogRepositoryErrorType.server;
  
  bool get requiresReauth => type == AuditLogRepositoryErrorType.session;
  
  @override
  String toString() => message;
}

enum AuditLogRepositoryErrorType {
  network,
  session,
  permission,
  server,
  format,
}