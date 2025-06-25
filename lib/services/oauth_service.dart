import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class OAuthService {
  static const String _baseUrl = 'http://localhost:8000';
  static const String _clientId = '9f3dc21f-a7e4-4f3f-90af-e584a7c0b665';
  static const String _redirectUri = 'myapp://alo/home';

  static String _generateCodeVerifier() {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(128, (i) => charset[random.nextInt(charset.length)]).join();
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    
    String base64String = base64.encode(digest.bytes);
    return base64String
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');
  }

  static String _generateState() {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(32, (i) => charset[random.nextInt(charset.length)]).join();
  }

  static Future<String> buildAuthUrl({bool isRegister = false}) async {
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final state = _generateState();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('code_verifier', codeVerifier);
    await prefs.setString('state', state);

    final params = {
      'response_type': 'code',
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'scope': '',
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'prompt': 'login',
      if (isRegister) 'action': 'register',
    };

    final uri = Uri.parse('$_baseUrl/oauth/authorize')
        .replace(queryParameters: params);
    
    return uri.toString();
  }

  static Future<Map<String, dynamic>?> exchangeCodeForTokens(String code, String state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedState = prefs.getString('state');
      final codeVerifier = prefs.getString('code_verifier');

      if (storedState != state) {
        throw Exception('Invalid state parameter');
      }

      if (codeVerifier == null) {
        throw Exception('Code verifier not found');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/oauth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': _clientId,
          'redirect_uri': _redirectUri,
          'code': code,
          'code_verifier': codeVerifier,
        },
      );

      if (response.statusCode == 200) {
        final tokens = json.decode(response.body);
        
        await prefs.setString('access_token', tokens['access_token']);
        if (tokens['refresh_token'] != null) {
          await prefs.setString('refresh_token', tokens['refresh_token']);
        }
        
        await prefs.remove('code_verifier');
        await prefs.remove('state');
        
        return tokens;
      } else {
        throw Exception('Failed to exchange code for tokens: ${response.body}');
      }
    } catch (e) {
      throw Exception('OAuth exchange failed: $e');
    }
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<bool> isAuthenticated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null || token.isEmpty) {
        return false;
      }
      
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/api/users/me'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
        
        if (response.statusCode == 200) {
          return true;
        } else {
          await prefs.remove('access_token');
          await prefs.remove('refresh_token');
          return false;
        }
      } catch (e) {
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = await getAccessToken();
      
      if (accessToken != null && accessToken.isNotEmpty) {
        await http.post(
          Uri.parse('$_baseUrl/api/users/auth/logout'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        );
      }
      
      final keysToRemove = ['access_token', 'refresh_token', 'code_verifier', 'state'];
      for (String key in keysToRemove) {
        await prefs.remove(key);
      }
      
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
  }
}