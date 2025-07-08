import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:lockity_flutter/core/app_config.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AuthToken {
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final int? expiresIn;

  const AuthToken({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'],
      tokenType: json['token_type'] ?? 'Bearer',
      expiresIn: json['expires_in'],
    );
  }

  Map<String, String> get authHeaders => {
    'Authorization': '$tokenType $accessToken',
    'Accept': 'application/json',
  };
}

class OAuthState {
  final String codeVerifier;
  final String codeChallenge;
  final String state;
  final String authorizeUrl;

  const OAuthState({
    required this.codeVerifier,
    required this.codeChallenge,
    required this.state,
    required this.authorizeUrl,
  });
}

abstract class TokenRepository {
  Future<void> saveToken(AuthToken token);
  Future<AuthToken?> getToken();
  Future<void> clearToken();
  Future<void> saveOAuthState(OAuthState oauthState);
  Future<OAuthState?> getOAuthState();
  Future<void> clearOAuthState();
}

class SharedPreferencesTokenRepository implements TokenRepository {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenTypeKey = 'token_type';
  static const String _expiresInKey = 'expires_in';
  static const String _codeVerifierKey = 'code_verifier';
  static const String _codeChallengeKey = 'code_challenge';
  static const String _stateKey = 'oauth_state';
  static const String _authorizeUrlKey = 'authorize_url';

  @override
  Future<void> saveToken(AuthToken token) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_accessTokenKey, token.accessToken),
      prefs.setString(_tokenTypeKey, token.tokenType),
      if (token.refreshToken != null)
        prefs.setString(_refreshTokenKey, token.refreshToken!),
      if (token.expiresIn != null)
        prefs.setInt(_expiresInKey, token.expiresIn!),
    ]);
  }

  @override
  Future<AuthToken?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);
    
    if (accessToken == null) return null;

    return AuthToken(
      accessToken: accessToken,
      refreshToken: prefs.getString(_refreshTokenKey),
      tokenType: prefs.getString(_tokenTypeKey) ?? 'Bearer',
      expiresIn: prefs.getInt(_expiresInKey),
    );
  }

  @override
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_tokenTypeKey),
      prefs.remove(_expiresInKey),
    ]);
  }

  @override
  Future<void> saveOAuthState(OAuthState oauthState) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_codeVerifierKey, oauthState.codeVerifier),
      prefs.setString(_codeChallengeKey, oauthState.codeChallenge),
      prefs.setString(_stateKey, oauthState.state),
      prefs.setString(_authorizeUrlKey, oauthState.authorizeUrl),
    ]);
  }

  @override
  Future<OAuthState?> getOAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    
    final codeVerifier = prefs.getString(_codeVerifierKey);
    final codeChallenge = prefs.getString(_codeChallengeKey);
    final state = prefs.getString(_stateKey);
    final authorizeUrl = prefs.getString(_authorizeUrlKey);

    if (codeVerifier == null || codeChallenge == null || 
        state == null || authorizeUrl == null) {
      return null;
    }

    return OAuthState(
      codeVerifier: codeVerifier,
      codeChallenge: codeChallenge,
      state: state,
      authorizeUrl: authorizeUrl,
    );
  }

  @override
  Future<void> clearOAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_codeVerifierKey),
      prefs.remove(_codeChallengeKey),
      prefs.remove(_stateKey),
      prefs.remove(_authorizeUrlKey),
    ]);
  }
}

class PKCECryptoService {
  static const String _charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  static const String _stateCharset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  
  static String generateCodeVerifier() {
    final random = Random.secure();
    const length = 128;
    return List.generate(length, (i) => 
      _charset[random.nextInt(_charset.length)]
    ).join();
  }

  static String generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    
    return base64.encode(digest.bytes)
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');
  }

  static String generateState() {
    final random = Random.secure();
    const length = 32;
    return List.generate(length, (i) => 
      _stateCharset[random.nextInt(_stateCharset.length)]
    ).join();
  }
}

abstract class HttpService {
  Future<http.Response> post(String url, {Map<String, String>? headers, dynamic body});
  Future<http.Response> get(String url, {Map<String, String>? headers});
}

class DefaultHttpService implements HttpService {
  final http.Client _client = http.Client();

  @override
  Future<http.Response> post(String url, {Map<String, String>? headers, dynamic body}) {
    if (body is Map<String, String>) {
      final formBody = body.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      return _client.post(Uri.parse(url), headers: headers, body: formBody);
    }
    
    return _client.post(Uri.parse(url), headers: headers, body: body);
  }

  @override
  Future<http.Response> get(String url, {Map<String, String>? headers}) {
    return _client.get(Uri.parse(url), headers: headers);
  }

  void dispose() {
    _client.close();
  }
}

class HttpClientWithCredentials implements HttpService {
  final http.Client _client = http.Client();

  @override
  Future<http.Response> post(String url, {Map<String, String>? headers, dynamic body}) async {
    final defaultHeaders = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (compatible; Flutter App)',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      ...?headers,
    };

    try {
      if (body is Map<String, String>) {
        final formBody = body.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        
        final formHeaders = {
          ...defaultHeaders,
          'Content-Type': 'application/x-www-form-urlencoded',
        };
        
        return await _client.post(
          Uri.parse(url), 
          headers: formHeaders, 
          body: formBody
        );
      }
      
      return await _client.post(
        Uri.parse(url), 
        headers: defaultHeaders, 
        body: body
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<http.Response> get(String url, {Map<String, String>? headers}) {
    final defaultHeaders = {
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 (compatible; Flutter App)',
      ...?headers,
    };
    
    return _client.get(Uri.parse(url), headers: defaultHeaders);
  }

  void dispose() {
    _client.close();
  }
}

class OAuthService {
  static final TokenRepository _tokenRepository = SharedPreferencesTokenRepository();
  static final HttpService _httpService = DefaultHttpService();
  static final HttpService _httpServiceWithCredentials = HttpClientWithCredentials();

  static Future<String> buildAuthorizationUrl({bool isRegister = false}) async {
    final codeVerifier = PKCECryptoService.generateCodeVerifier();
    final codeChallenge = PKCECryptoService.generateCodeChallenge(codeVerifier);
    final state = PKCECryptoService.generateState();

    final authParams = {
      'response_type': 'code',
      'client_id': AppConfig.clientId,
      'redirect_uri': AppConfig.redirectUri,
      'scope': AppConfig.oauthScope,
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    };

    final authorizeUrl = Uri.parse(AppConfig.authUrl)
        .replace(queryParameters: authParams)
        .toString();

    final oauthState = OAuthState(
      codeVerifier: codeVerifier,
      codeChallenge: codeChallenge,
      state: state,
      authorizeUrl: authorizeUrl,
    );

    await _tokenRepository.saveOAuthState(oauthState);

    return isRegister ? AppConfig.registerUrl : authorizeUrl;
  }

  static Future<String?> getPendingOAuthUrl() async {
    final oauthState = await _tokenRepository.getOAuthState();
    return oauthState?.authorizeUrl;
  }

  static Future<AuthToken> exchangeCodeForTokens(String code, String receivedState) async {
    final oauthState = await _tokenRepository.getOAuthState();
    
    if (oauthState == null) {
      throw const OAuthException('OAuth state not found. Please restart the login process.');
    }

    if (oauthState.state != receivedState) {
      throw const OAuthException('Invalid state parameter - possible CSRF attack');
    }

    final tokenRequestParams = {
      'grant_type': 'authorization_code',
      'client_id': AppConfig.clientId,
      'redirect_uri': AppConfig.redirectUri,
      'code': code,
      'code_verifier': oauthState.codeVerifier,
    };

    final formBody = tokenRequestParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    try {
      final response = await _httpService.post(
        AppConfig.tokenUrl,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: formBody,
      ).timeout(Duration(seconds: AppConfig.tokenExchangeTimeout));

      if (response.statusCode != 200) {
        throw OAuthException(
          'Token exchange failed with status ${response.statusCode}: ${response.body}'
        );
      }

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      
      if (responseData['access_token'] == null) {
        throw const OAuthException('No access token in response');
      }

      final token = AuthToken.fromJson(responseData);
      
      await _tokenRepository.saveToken(token);
      await _tokenRepository.clearOAuthState();

      return token;
    } catch (e) {
      if (e is OAuthException) rethrow;
      throw OAuthException('Token exchange failed: $e');
    }
  }

  static Future<bool> isAuthenticated() async {
    try {
      final token = await _tokenRepository.getToken();
      
      if (token == null) {
        return false;
      }

      final response = await _httpService.get(
        AppConfig.userMeUrl,
        headers: token.authHeaders,
      ).timeout(Duration(seconds: AppConfig.httpTimeout));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return responseData['success'] == true;
      } else if (response.statusCode == 401) {
        await _tokenRepository.clearToken();
        return false;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> logout() async {
    try {
      final token = await _tokenRepository.getToken();
      
      if (token != null) {
        try {
          final apiLogoutResponse = await _httpService.post(
            AppConfig.logoutUrl,
            headers: {
              ...token.authHeaders,
              'Content-Type': 'application/json',
            },
          ).timeout(Duration(seconds: AppConfig.httpTimeout));

          if (apiLogoutResponse.statusCode == 200) {
            final responseData = json.decode(apiLogoutResponse.body) as Map<String, dynamic>;
            
            if (responseData['success'] == true) {
              await _performWebLogoutWithCredentials();
            }
          }
        } catch (e) {
          await _performWebLogoutWithCredentials();
        }
      } else {
        await _performWebLogoutWithCredentials();
      }
    } finally {
      await Future.wait([
        _tokenRepository.clearToken(),
        _tokenRepository.clearOAuthState(),
        _clearWebViewData(),
      ]);
    }
  }

  static Future<void> _clearWebViewData() async {
    try {
      final cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();
    } catch (e) {
      // 
    }
  }

  static Future<Map<String, dynamic>?> getUserInfo() async {
    final token = await _tokenRepository.getToken();
    
    if (token == null) return null;

    try {
      final response = await _httpService.get(
        AppConfig.userMeUrl,
        headers: token.authHeaders,
      ).timeout(Duration(seconds: AppConfig.httpTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['success'] == true ? data['data'] : null;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<AuthToken?> getStoredToken() async {
    return await _tokenRepository.getToken();
  }

  static Future<void> clearAllData() async {
    await Future.wait([
      _tokenRepository.clearToken(),
      _tokenRepository.clearOAuthState(),
      _clearWebViewData(),
    ]);
  }

  static Future<void> _performWebLogoutWithCredentials() async {
    try {
      final webLogoutUrl = AppConfig.webLogoutUrl;
      
      final webLogoutResponse = await _httpServiceWithCredentials.post(
        webLogoutUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: AppConfig.httpTimeout));

      // 
    } catch (e) {
      // 
    }
  }
}

class OAuthException implements Exception {
  final String message;
  
  const OAuthException(this.message);
  
  @override
  String toString() => 'OAuthException: $message';
}