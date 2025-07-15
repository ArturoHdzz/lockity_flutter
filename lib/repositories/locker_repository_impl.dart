import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lockity_flutter/core/app_config.dart';
import 'package:lockity_flutter/models/locker_config_response.dart';
import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/models/locker_response.dart';
import 'package:lockity_flutter/repositories/locker_repository.dart';
import 'package:lockity_flutter/services/oauth_service.dart';

class LockerRepositoryImpl implements LockerRepository {
  final http.Client _httpClient;

  LockerRepositoryImpl({http.Client? httpClient}) 
    : _httpClient = httpClient ?? http.Client();

  @override
  Future<LockerListResponse> getLockers(LockerListRequest request) async {
    try {
      final token = await OAuthService.getStoredToken();
      if (token == null) {
        throw const LockerRepositoryException._session('Authentication required');
      }

      final uri = Uri.parse(AppConfig.lockersUrl).replace(
        queryParameters: request.toQueryParameters(),
      );

      if (AppConfig.debugMode) {
        debugPrint('🌐 LOCKER_REPO: Making GET request to: $uri');
        debugPrint('🔐 LOCKER_REPO: Headers: ${token.authHeaders}');
      }

      final response = await _httpClient.get(
        uri,
        headers: {
          ...?token.authHeaders,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: AppConfig.httpTimeout));

      if (AppConfig.debugMode) {
        debugPrint('🌐 LOCKER_REPO: Response status: ${response.statusCode}');
        debugPrint('🌐 LOCKER_REPO: Response body: ${response.body}');
      }

      return _handleLockerListResponse(response);
    } on LockerRepositoryException {
      rethrow;
    } catch (e) {
      debugPrint('❌ LOCKER_REPO: Network error: $e');
      throw LockerRepositoryException._network(
        'Please check your internet connection and try again.',
      );
    }
  }

  @override
  Future<LockerOperationResponse> updateLockerStatus(UpdateLockerStatusRequest request) async {
    try {
      final token = await OAuthService.getStoredToken();
      if (token == null) {
        throw const LockerRepositoryException._session('Authentication required');
      }

      final url = '${AppConfig.baseUrl}/api/lockers/${request.lockerId}/${request.statusString}';
      
      if (AppConfig.debugMode) {
        debugPrint('🌐 LOCKER_REPO: Making PUT request to: $url');
        debugPrint('🔐 LOCKER_REPO: Headers: ${token.authHeaders}');
      }
      
      final response = await _httpClient.put(
        Uri.parse(url),
        headers: {
          ...?token?.authHeaders,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: AppConfig.httpTimeout));

      if (AppConfig.debugMode) {
        debugPrint('🌐 LOCKER_REPO: Response status: ${response.statusCode}');
        debugPrint('🌐 LOCKER_REPO: Response body: ${response.body}');
      }

      return _handleOperationResponse(response);
    } on LockerRepositoryException {
      rethrow;
    } catch (e) {
      debugPrint('❌ LOCKER_REPO: Network error: $e');
      throw LockerRepositoryException._network(
        'Please check your internet connection and try again.',
      );
    }
  }

  @override
  Future<LockerConfigResponse> getLockerConfig(String serialNumber) async {
    final url = '${AppConfig.lockerConfigEndpoint}/$serialNumber';
    final response = await _httpClient.get(
      Uri.parse(url),
      headers: {
        'x-iot-key': AppConfig.iotSecretKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(Duration(seconds: AppConfig.httpTimeout));

    debugPrint('🔴 LockerConfig status: ${response.statusCode}');
    debugPrint('🔴 LockerConfig body: ${response.body}');

    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw LockerRepositoryException._notFound('Locker not found for serial: $serialNumber');
      }
      throw Exception('Failed to load locker config: ${response.statusCode} - ${response.body}');
    }
    return LockerConfigResponse.fromJson(json.decode(response.body));
  }

  LockerListResponse _handleLockerListResponse(http.Response response) {
    switch (response.statusCode) {
      case 401:
        throw const LockerRepositoryException._session(
          'Your session has expired. Please sign in again.'
        );
      case 403:
        throw const LockerRepositoryException._permission(
          'You don\'t have permission to view lockers.'
        );
      case 500:
        throw const LockerRepositoryException._server(
          'Server error occurred. Please try again later.'
        );
      case 200:
        return _parseLockerListResponse(response);
      default:
        throw LockerRepositoryException._server(
          'Unable to load lockers. Please try again later.'
        );
    }
  }

  LockerOperationResponse _handleOperationResponse(http.Response response) {
    switch (response.statusCode) {
      case 401:
        throw const LockerRepositoryException._session(
          'Your session has expired. Please sign in again.'
        );
      case 403:
        throw const LockerRepositoryException._permission(
          'You don\'t have permission to control this locker.'
        );
      case 404:
        throw const LockerRepositoryException._notFound(
          'Locker not found or you don\'t have access to it.'
        );
      case 400:
        throw const LockerRepositoryException._validation(
          'Invalid locker ID or status provided.'
        );
      case 500:
        throw const LockerRepositoryException._server(
          'Server error occurred. Please try again later.'
        );
      case 200:
        return _parseOperationResponse(response);
      default:
        throw LockerRepositoryException._server(
          'Unable to complete operation. Please try again later.'
        );
    }
  }

  LockerListResponse _parseLockerListResponse(http.Response response) {
    final responseData = _decodeResponse(response);
    
    if (responseData['success'] != true) {
      throw LockerRepositoryException._server(
        responseData['message'] ?? 'Failed to load lockers.'
      );
    }

    try {
      return LockerListResponse.fromJson(responseData);
    } catch (e) {
      throw const LockerRepositoryException._format(
        'Unable to process lockers data. Please try again.'
      );
    }
  }

  LockerOperationResponse _parseOperationResponse(http.Response response) {
    final responseData = _decodeResponse(response);

    try {
      return LockerOperationResponse.fromJson(responseData);
    } catch (e) {
      throw const LockerRepositoryException._format(
        'Unable to process operation response. Please try again.'
      );
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw const LockerRepositoryException._format(
        'Server response is invalid. Please try again.'
      );
    }
  }

  void dispose() => _httpClient.close();
}

class LockerRepositoryException implements Exception {
  final String message;
  final LockerRepositoryErrorType type;
  
  const LockerRepositoryException._(this.message, this.type);
  
  const LockerRepositoryException._network(String message) 
    : this._(message, LockerRepositoryErrorType.network);
    
  const LockerRepositoryException._session(String message) 
    : this._(message, LockerRepositoryErrorType.session);
    
  const LockerRepositoryException._permission(String message) 
    : this._(message, LockerRepositoryErrorType.permission);
    
  const LockerRepositoryException._server(String message) 
    : this._(message, LockerRepositoryErrorType.server);
    
  const LockerRepositoryException._format(String message) 
    : this._(message, LockerRepositoryErrorType.format);

  const LockerRepositoryException._notFound(String message) 
    : this._(message, LockerRepositoryErrorType.notFound);
    
  const LockerRepositoryException._validation(String message) 
    : this._(message, LockerRepositoryErrorType.validation);
  
  bool get isRetryable => type == LockerRepositoryErrorType.network || 
                         type == LockerRepositoryErrorType.server;
  
  bool get requiresReauth => type == LockerRepositoryErrorType.session;
  
  @override
  String toString() => message;
}

enum LockerRepositoryErrorType {
  network,
  session,
  permission,
  server,
  format,
  notFound,
  validation,
}