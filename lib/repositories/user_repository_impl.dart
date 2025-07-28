import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lockity_flutter/core/app_config.dart';
import 'package:lockity_flutter/models/user.dart';
import 'package:lockity_flutter/models/user_update_request.dart';
import 'package:lockity_flutter/repositories/user_repository.dart';
import 'package:lockity_flutter/services/oauth_service.dart';

class UserRepositoryImpl implements UserRepository {
  final http.Client _httpClient;
  User? _user;

  UserRepositoryImpl({http.Client? httpClient}) 
    : _httpClient = httpClient ?? http.Client();

  @override
  Future<User> getCurrentUser() async {
    try {
      final token = await OAuthService.getStoredToken();
      if (token == null) {
        throw const UserRepositoryException._internal('Authentication required');
      }
      final response = await _httpClient.get(
        Uri.parse(AppConfig.userMeUrl),
        headers: {
          ...token.authHeaders,
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: AppConfig.httpTimeout));
      final user = await _handleResponse(response, _parseUserResponse);
      _user = user;
      return user;
    } on UserRepositoryException {
      rethrow;
    } catch (e) {
      throw UserRepositoryException._network(
        'Please check your internet connection and try again.',
      );
    }
  }

  @override
  Future<User> updateCurrentUser(UserUpdateRequest request) async {
    try {
      final token = await OAuthService.getStoredToken();
      if (token == null) {
        throw const UserRepositoryException._internal('Authentication required');
      }
      final response = await _httpClient.put(
        Uri.parse(AppConfig.userMeUrl),
        headers: {
          ...token.authHeaders,
          'Content-Type': 'application/json',
        },
        body: json.encode(request.toJson()),
      ).timeout(Duration(seconds: AppConfig.httpTimeout));
      if (response.statusCode == 422) {
        return _handleValidationErrors(response);
      }
      final user = await _handleResponse(response, _parseUserResponse);
      _user = user;
      return user;
    } on UserRepositoryException {
      rethrow;
    } catch (e) {
      throw UserRepositoryException._network(
        'Please check your internet connection and try again.',
      );
    }
  }

  T _handleResponse<T>(http.Response response, T Function(Map<String, dynamic>) parser) {
    switch (response.statusCode) {
      case 401:
        throw const UserRepositoryException._session(
          'Your session has expired. Please sign in again.'
        );
      case 403:
        throw const UserRepositoryException._permission(
          'You don\'t have permission to perform this action.'
        );
      case 400:
        throw const UserRepositoryException._format(
          'The information provided is not valid. Please check your data.'
        );
      case 200:
        return _parseSuccessResponse(response, parser);
      default:
        throw UserRepositoryException._server(
          'Unable to process request at this time. Please try again later.'
        );
    }
  }

  T _parseSuccessResponse<T>(http.Response response, T Function(Map<String, dynamic>) parser) {
    final responseData = _decodeResponse(response);
    if (responseData['success'] != true) {
      throw UserRepositoryException._server(
        responseData['message'] ?? 'Request was not successful.'
      );
    }
    final data = responseData['data'] as Map<String, dynamic>?;
    if (data == null) {
      if (_user != null && T == User) {
        return _user as T;
      }
      throw const UserRepositoryException._format(
        'Profile updated, but no user data returned. Please reload your profile.'
      );
    }
    try {
      return parser(data);
    } catch (e) {
      throw const UserRepositoryException._format(
        'Unable to process server response. Please try again.'
      );
    }
  }

  User _parseUserResponse(Map<String, dynamic> data) => User.fromJson(data);

  User _handleValidationErrors(http.Response response) {
    final responseData = _decodeResponse(response);
    final errors = responseData['errors'] as Map<String, dynamic>?;
    if (errors != null) {
      final userFriendlyErrors = _convertToUserFriendlyErrors(errors);
      throw UserRepositoryException._validation(userFriendlyErrors.join(' '));
    }
    throw UserRepositoryException._validation(
      responseData['message'] ?? 'Please check your information and try again.'
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw const UserRepositoryException._format(
        'Server response is invalid. Please try again.'
      );
    }
  }

  List<String> _convertToUserFriendlyErrors(Map<String, dynamic> errors) {
    final userFriendlyErrors = <String>[];
    errors.forEach((field, messages) {
      if (messages is List) {
        for (String message in messages.cast<String>()) {
          final friendlyMessage = _translateError(field, message);
          if (!userFriendlyErrors.contains(friendlyMessage)) {
            userFriendlyErrors.add(friendlyMessage);
          }
        }
      }
    });
    return userFriendlyErrors.isEmpty 
      ? ['Please check your information and try again.']
      : userFriendlyErrors;
  }

  String _translateError(String field, String technicalMessage) {
    final lowerMessage = technicalMessage.toLowerCase();
    final lowerField = field.toLowerCase();
    if (lowerMessage.contains('must not be greater than') || 
        lowerMessage.contains('too long')) {
      return '${_getFieldDisplayName(lowerField)} is too long. Please use fewer characters.';
    }
    if (lowerMessage.contains('contain only letters') ||
        lowerMessage.contains('letters and spaces')) {
      return '${_getFieldDisplayName(lowerField)} can only contain letters and spaces.';
    }
    if (lowerMessage.contains('must be at least') ||
        lowerMessage.contains('too short')) {
      return '${_getFieldDisplayName(lowerField)} must be at least 3 characters long.';
    }
    if (lowerMessage.contains('valid email') ||
        lowerMessage.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    if (lowerMessage.contains('already been taken') ||
        lowerMessage.contains('already exists')) {
      return 'This email is already registered. Please use a different email address.';
    }
    if (lowerMessage.contains('required') ||
        lowerMessage.contains('cannot be empty')) {
      return '${_getFieldDisplayName(lowerField)} is required.';
    }
    return technicalMessage;
  }

  String _getFieldDisplayName(String field) {
    switch (field) {
      case 'name': return 'First name';
      case 'last_name': return 'Last name';
      case 'second_last_name': return 'Second last name';
      case 'email': return 'Email';
      default: return field.replaceAll('_', ' ').split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
    }
  }

  void dispose() => _httpClient.close();
}

class UserRepositoryException implements Exception {
  final String message;
  final UserRepositoryErrorType type;
  
  const UserRepositoryException._(this.message, this.type);
  
  const UserRepositoryException._network(String message) 
    : this._(message, UserRepositoryErrorType.network);
    
  const UserRepositoryException._validation(String message) 
    : this._(message, UserRepositoryErrorType.validation);
    
  const UserRepositoryException._session(String message) 
    : this._(message, UserRepositoryErrorType.session);
    
  const UserRepositoryException._permission(String message) 
    : this._(message, UserRepositoryErrorType.permission);
    
  const UserRepositoryException._server(String message) 
    : this._(message, UserRepositoryErrorType.server);
    
  const UserRepositoryException._format(String message) 
    : this._(message, UserRepositoryErrorType.format);
    
  const UserRepositoryException._internal(String message) 
    : this._(message, UserRepositoryErrorType.internal);
  
  bool get isRetryable => type == UserRepositoryErrorType.network || 
                         type == UserRepositoryErrorType.server;
  
  bool get requiresReauth => type == UserRepositoryErrorType.session;
  
  @override
  String toString() => message;
}

enum UserRepositoryErrorType {
  network,
  validation, 
  session,
  permission,
  server,
  format,
  internal,
}