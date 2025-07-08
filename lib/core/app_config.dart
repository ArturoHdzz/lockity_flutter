import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? '';
  static String get clientId => dotenv.env['CLIENT_ID'] ?? '';
  static String get redirectUri => dotenv.env['REDIRECT_URI'] ?? '';
  
  static String get loginEndpoint => dotenv.env['LOGIN_ENDPOINT'] ?? '';
  static String get registerEndpoint => dotenv.env['REGISTER_ENDPOINT'] ?? '';
  static String get authEndpoint => dotenv.env['AUTH_ENDPOINT'] ?? '';
  static String get tokenEndpoint => dotenv.env['TOKEN_ENDPOINT'] ?? '';
  static String get userMeEndpoint => dotenv.env['USER_ME_ENDPOINT'] ?? '/api/users/me';
  static String get logoutEndpoint => dotenv.env['LOGOUT_ENDPOINT'] ?? '';
  static String get webLogoutEndpoint => dotenv.env['WEB_LOGOUT_ENDPOINT'] ?? '';
  
  static String get loginUrl => '$baseUrl$loginEndpoint';
  static String get registerUrl => '$baseUrl$registerEndpoint';
  static String get authUrl => '$baseUrl$authEndpoint';
  static String get tokenUrl => '$baseUrl$tokenEndpoint';
  static String get userMeUrl => '$baseUrl$userMeEndpoint';
  static String get logoutUrl => '$baseUrl$logoutEndpoint';
  static String get webLogoutUrl => '$baseUrl$webLogoutEndpoint';
  
  static String get oauthScope => dotenv.env['OAUTH_SCOPE'] ?? '';
  static String get oauthPrompt => dotenv.env['OAUTH_PROMPT'] ?? '';
  static String get codeChallengeMethod => dotenv.env['CODE_CHALLENGE_METHOD'] ?? '';
  static String get grantType => dotenv.env['GRANT_TYPE'] ?? '';
  static String get responseType => dotenv.env['RESPONSE_TYPE'] ?? '';
  
  static String get appName => dotenv.env['APP_NAME'] ?? '';
  static bool get debugMode => dotenv.env['DEBUG_MODE'] == 'true';
  
  static int get authTimeout => int.tryParse(dotenv.env['AUTH_TIMEOUT'] ?? '') ?? 30;
  static int get httpTimeout => int.tryParse(dotenv.env['HTTP_TIMEOUT'] ?? '') ?? 45;
  static int get tokenExchangeTimeout => int.tryParse(dotenv.env['TOKEN_EXCHANGE_TIMEOUT'] ?? '') ?? 60;
  
  static Future<void> load() async {
    await dotenv.load(fileName: "assets/config/.env");
  }
}