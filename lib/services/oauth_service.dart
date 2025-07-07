import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:lockity_flutter/core/app_config.dart';

class OAuthService {
  static String get _clientId => AppConfig.clientId;
  static String get _redirectUri => AppConfig.redirectUri;

  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

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

    final oauthParams = {
      'response_type': AppConfig.responseType,
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'scope': AppConfig.oauthScope,
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': AppConfig.codeChallengeMethod,
      'prompt': AppConfig.oauthPrompt,
    };

    final oauthUrl = Uri.parse(AppConfig.authUrl).replace(queryParameters: oauthParams);
    await prefs.setString('oauth_url', oauthUrl.toString());

    return isRegister ? AppConfig.registerUrl : AppConfig.loginUrl;
  }

  static Future<String> buildOAuthUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOAuthUrl = prefs.getString('oauth_url');

    if (savedOAuthUrl != null) {
      return savedOAuthUrl;
    }

    final codeVerifier = prefs.getString('code_verifier');
    final state = prefs.getString('state');

    if (codeVerifier == null || state == null) {
      throw Exception('OAuth parameters not found. Please restart the login process.');
    }

    final codeChallenge = _generateCodeChallenge(codeVerifier);
    
    final params = {
      'response_type': AppConfig.responseType,
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'scope': AppConfig.oauthScope,
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': AppConfig.codeChallengeMethod,
      'prompt': AppConfig.oauthPrompt,
    };

    final uri = Uri.parse(AppConfig.authUrl).replace(queryParameters: params);
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

      final requestBody = {
        'grant_type': AppConfig.grantType,
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'code': code,
        'code_verifier': codeVerifier,
      };

      final response = await http.post(
        Uri.parse(AppConfig.tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: requestBody,
      ).timeout(Duration(seconds: AppConfig.tokenExchangeTimeout));

      if (response.statusCode == 200) {
        final tokens = json.decode(response.body);
        
        if (tokens['access_token'] != null) {
          await prefs.setString('access_token', tokens['access_token']);
          if (tokens['refresh_token'] != null) {
            await prefs.setString('refresh_token', tokens['refresh_token']);
          }
          
          await prefs.remove('code_verifier');
          await prefs.remove('state');
          await prefs.remove('oauth_url');
          
          return tokens;
        } else {
          throw Exception('No access token in response');
        }
      } else {
        throw Exception('Token exchange failed with status ${response.statusCode}: ${response.body}');
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
          Uri.parse(AppConfig.userMeUrl), 
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(Duration(seconds: AppConfig.httpTimeout)); 
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            return true;
          } else {
            await prefs.remove('access_token');
            await prefs.remove('refresh_token');
            return false;
          }
        } else if (response.statusCode == 401) {
          await prefs.remove('access_token');
          await prefs.remove('refresh_token');
          return false;
        } else {
          return false;
        }
      } catch (e) {
        return false;
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
        try {
          await http.post(
            Uri.parse(AppConfig.logoutUrl),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ).timeout(Duration(seconds: AppConfig.httpTimeout));
        } catch (e) {
          // 
        }
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

  static Future<Map<String, dynamic>?> getUserInfo() async {
    final accessToken = await getAccessToken();
    
    if (accessToken == null) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse(AppConfig.userMeUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: AppConfig.httpTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> checkWebSession() async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.authUrl),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'User-Agent': 'Mozilla/5.0 (compatible; Lockity-Flutter/1.0)',
        },
      ).timeout(Duration(seconds: AppConfig.httpTimeout));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}