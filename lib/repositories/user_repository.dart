import 'package:lockity_flutter/models/user.dart';
import 'package:lockity_flutter/models/user_update_request.dart';

abstract class UserRepository {
  Future<User> getCurrentUser();
  Future<User> updateCurrentUser(UserUpdateRequest request);
}