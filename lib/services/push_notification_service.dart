import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PushNotificationService {
  static final String _baseUrl = dotenv.env['NOTIFICATIONS_BASE_URL'] ?? 'http://64.23.237.187:8002';
  static final String _registerEndpoint = '/api/notifications/register';
  static final String _unregisterEndpoint = '/api/notifications/unregister';

  static Future<bool> registerToken({
    required String token,
    required String accessToken,
    required String platform,
  }) async {
    final url = '$_baseUrl$_registerEndpoint';
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'device_token': token,
        'device_type': 'mobile',
        'platform': platform,
      }),
    );
    print('FCM register response: ${response.statusCode} - ${response.body}');
    return response.statusCode == 201;
  }

  static Future<bool> unregisterToken({
    required String token,
    required String accessToken,
  }) async {
    final url = '$_baseUrl$_unregisterEndpoint';
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'device_token': token,
      }),
    );
    return response.statusCode == 200;
  }
}