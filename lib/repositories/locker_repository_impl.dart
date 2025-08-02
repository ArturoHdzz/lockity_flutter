import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lockity_flutter/core/app_config.dart';
import 'package:lockity_flutter/models/locker_config_response.dart';
import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/models/locker_response.dart';
import 'package:lockity_flutter/models/compartment_status_response.dart';
import 'package:lockity_flutter/repositories/locker_repository.dart';
import 'package:lockity_flutter/services/oauth_service.dart';

class LockerRepositoryImpl implements LockerRepository {
  final http.Client _httpClient;

  LockerRepositoryImpl({http.Client? httpClient}) 
    : _httpClient = httpClient ?? http.Client();

  @override
  Future<LockerListResponse> getLockers(LockerListRequest request) async {
    final token = await OAuthService.getStoredToken();
    if (token == null) {
      throw const LockerRepositoryException._session('Authentication required');
    }
    final uri = Uri.parse(AppConfig.lockersUrl).replace(
      queryParameters: request.toQueryParameters(),
    );
    final response = await _httpClient.get(
      uri,
      headers: {
        ...token.authHeaders,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(Duration(seconds: AppConfig.httpTimeout));
    return _handleLockerListResponse(response);
  }

  @override
  Future<LockerOperationResponse> updateLockerStatus(UpdateLockerStatusRequest request) async {
    final token = await OAuthService.getStoredToken();
    if (token == null) {
      throw const LockerRepositoryException._session('Authentication required');
    }
    final url = '${AppConfig.lockerConfigEndpoint}/${request.serialNumber}/${request.compartmentNumber}/${request.statusString}';
    final response = await _httpClient.put(
      Uri.parse(url),
      headers: {
        'x-iot-key': AppConfig.iotSecretKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(Duration(seconds: AppConfig.httpTimeout));
    return _handleOperationResponse(response);
  }

  @override
  Future<LockerConfigResponse> getLockerConfig(String serialNumber) async {
    final url = '${AppConfig.lockerConfigEndpoint}/$serialNumber';
    if (url.isEmpty || !url.startsWith('http')) {
      throw Exception('Locker config URL is invalid: $url');
    }
    final response = await _httpClient.get(
      Uri.parse(url),
      headers: {
        'x-iot-key': AppConfig.iotSecretKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(Duration(seconds: AppConfig.httpTimeout));
    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw LockerRepositoryException._notFound('Locker not found for serial: $serialNumber');
      }
      throw Exception('Failed to load locker config: ${response.statusCode} - ${response.body}');
    }
    return LockerConfigResponse.fromJson(json.decode(response.body));
  }

  @override
  Future<CompartmentStatusResponse> getCompartmentStatus(
    String serialNumber, 
    int compartmentNumber
  ) async {
    final token = await OAuthService.getStoredToken();
    if (token == null) {
      throw const LockerRepositoryException._session('Authentication required');
    }

    final baseStatusUrl = AppConfig.lockerStatusEndpoint;
    final url = '$baseStatusUrl/$serialNumber/$compartmentNumber';
    
    print('🔍 Consultando estado del compartimento: $url');
    
    final response = await _httpClient.get(
      Uri.parse(url),
      headers: {
        ...token.authHeaders,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(Duration(seconds: AppConfig.httpTimeout));

    print('📡 Respuesta del estado: ${response.statusCode} - ${response.body}');

    return _handleCompartmentStatusResponse(response);
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

  CompartmentStatusResponse _handleCompartmentStatusResponse(http.Response response) {
    switch (response.statusCode) {
      case 401:
        throw const LockerRepositoryException._session(
          'Your session has expired. Please sign in again.'
        );
      case 403:
        throw const LockerRepositoryException._permission(
          'You don\'t have permission to access this compartment.'
        );
      case 404:
        throw const LockerRepositoryException._notFound(
          'Compartment not found or you don\'t have access to it.'
        );
      case 400:
        throw const LockerRepositoryException._validation(
          'Invalid serial number or compartment number provided.'
        );
      case 500:
        throw const LockerRepositoryException._server(
          'Server error occurred. Please try again later.'
        );
      case 200:
        return _parseCompartmentStatusResponse(response);
      default:
        throw LockerRepositoryException._server(
          'Unable to get compartment status. Please try again later.'
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
    return LockerListResponse.fromJson(responseData);
  }

  LockerOperationResponse _parseOperationResponse(http.Response response) {
    final responseData = _decodeResponse(response);
    return LockerOperationResponse.fromJson(responseData);
  }

  CompartmentStatusResponse _parseCompartmentStatusResponse(http.Response response) {
    final responseData = _decodeResponse(response);
    return CompartmentStatusResponse.fromJson(responseData);
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