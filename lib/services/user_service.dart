import 'package:lockity_flutter/services/oauth_service.dart';
import 'package:flutter/foundation.dart';

class UserService {
  static String? _cachedUserId;

  static Future<String?> getCurrentUserId() async {
    if (_cachedUserId != null) return _cachedUserId;

    try {
      final userInfo = await OAuthService.getUserInfo();
      
      if (userInfo != null && userInfo['id'] != null) {
        _cachedUserId = userInfo['id'].toString();
        debugPrint('✅ USER: Retrieved user ID: $_cachedUserId');
        return _cachedUserId;
      }
    } catch (e) {
      debugPrint('❌ USER: Error getting user ID: $e');
    }

    debugPrint('⚠️ USER: Using fallback user ID for development');
    return '1'; // Fallback para desarrollo
  }

  static void clearCache() {
    _cachedUserId = null;
    debugPrint('🧹 USER: Cache cleared');
  }
}