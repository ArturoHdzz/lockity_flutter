import 'dart:math';
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
  static String get auditLogsEndpoint => dotenv.env['AUDIT_LOGS_ENDPOINT'] ?? '/api/audit-logs';
  static String get lockersEndpoint => dotenv.env['LOCKERS_ENDPOINT'] ?? '/api/lockers';

  static String get loginUrl => '$baseUrl$loginEndpoint';
  static String get registerUrl => '$baseUrl$registerEndpoint';
  static String get authUrl => '$baseUrl$authEndpoint';
  static String get tokenUrl => '$baseUrl$tokenEndpoint';
  static String get userMeUrl => '$baseUrl$userMeEndpoint';
  static String get logoutUrl => '$baseUrl$logoutEndpoint';
  static String get webLogoutUrl => '$baseUrl$webLogoutEndpoint';
  static String get auditLogsUrl => dotenv.env['AUDIT_LOGS_ENDPOINT'] ?? 'http://64.23.237.187:8002/api/access-logs';
  static String get lockersUrl => dotenv.env['LOCKERS_ENDPOINT'] ?? '$baseUrl/api/lockers';
  static String get lockerConfigEndpoint => dotenv.env['LOCKER_CONFIG_ENDPOINT'] ?? '$baseUrl/api/locker-config';
  static String get lockerStatusEndpoint => dotenv.env['LOCKER_STATUS_ENDPOINT'] ?? '$baseUrl/api/lockers/compartment/status';

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

  static String get mqttBrokerHost => dotenv.env['MQTT_BROKER_HOST'] ?? '64.23.237.187';
  static int get mqttBrokerPort => int.tryParse(dotenv.env['MQTT_BROKER_PORT'] ?? '') ?? 8883;
  static String get mqttClientId {
    final baseClientId = dotenv.env['MQTT_CLIENT_ID'] ?? 'lockity_flutter_client';
    final randomSuffix = DateTime.now().millisecondsSinceEpoch.toString() + '_' + Random().nextInt(1000).toString();
    return '$baseClientId\_$randomSuffix';
  }
  static String get mqttUsername => dotenv.env['MQTT_USERNAME'] ?? 'esp32';
  static String get mqttPassword => dotenv.env['MQTT_PASSWORD'] ?? '';

  static bool get useMockAuditLogs => dotenv.env['USE_MOCK_AUDIT_LOGS'] == 'true';
  static bool get useMockLockers => dotenv.env['USE_MOCK_LOCKERS'] == 'true';
  static String get iotSecretKey => dotenv.env['IOT_SECRET_KEY'] ?? '';
}