import 'package:lockity_flutter/models/user.dart';
import 'package:lockity_flutter/repositories/user_repository.dart';

class GetCurrentUserUseCase {
  final UserRepository _userRepository;

  const GetCurrentUserUseCase(this._userRepository);

  Future<User> execute() async {
    try {
      return await _userRepository.getCurrentUser();
    } catch (e) {
      rethrow;
    }
  }
}