import 'package:lockity_flutter/models/user.dart';
import 'package:lockity_flutter/models/user_update_request.dart';
import 'package:lockity_flutter/repositories/user_repository.dart';

class UpdateUserUseCase {
  final UserRepository _userRepository;

  const UpdateUserUseCase(this._userRepository);

  Future<User> execute(UserUpdateRequest request) async {
    // Validación local antes de enviar al servidor
    if (!request.isValid) {
      throw UpdateUserException(
        'Validation failed: ${request.validationErrors.join(', ')}',
      );
    }

    try {
      return await _userRepository.updateCurrentUser(request);
    } catch (e) {
      rethrow;
    }
  }
}

class UpdateUserException implements Exception {
  final String message;
  
  const UpdateUserException(this.message);
  
  @override
  String toString() => 'UpdateUserException: $message';
}