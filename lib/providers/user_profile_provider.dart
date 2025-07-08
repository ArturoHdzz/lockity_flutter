import 'package:flutter/foundation.dart';
import 'package:lockity_flutter/models/user.dart';
import 'package:lockity_flutter/models/user_update_request.dart';
import 'package:lockity_flutter/use_cases/get_current_user_use_case.dart';
import 'package:lockity_flutter/use_cases/update_user_use_case.dart';

enum UserProfileState { initial, loading, loaded, updating, updated, error }

class UserProfileProvider extends ChangeNotifier {
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final UpdateUserUseCase _updateUserUseCase;

  UserProfileProvider({
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required UpdateUserUseCase updateUserUseCase,
  }) : _getCurrentUserUseCase = getCurrentUserUseCase,
       _updateUserUseCase = updateUserUseCase;

  UserProfileState _state = UserProfileState.initial;
  User? _user;
  String? _errorMessage;

  UserProfileState get state => _state;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == UserProfileState.loading;
  bool get isUpdating => _state == UserProfileState.updating;
  bool get hasError => _state == UserProfileState.error;
  bool get hasUser => _user != null;

  Future<void> loadUserProfile() async {
    if (_state == UserProfileState.loading) return;

    _setState(UserProfileState.loading);
    _clearError();

    try {
      _user = await _getCurrentUserUseCase.execute();
      _setState(UserProfileState.loaded);
    } catch (e) {
      _setError(_extractUserFriendlyMessage(e.toString()));
    }
  }

  Future<bool> updateUserProfile({
    required String name,
    required String lastName,
    required String secondLastName,
    required String email,
  }) async {
    if (_state == UserProfileState.updating) return false;

    _setState(UserProfileState.updating);
    _clearError();

    try {
      final request = UserUpdateRequest(
        name: name.trim(),
        lastName: lastName.trim(),
        secondLastName: secondLastName.trim(),
        email: email.trim(),
      );

      _user = await _updateUserUseCase.execute(request);
      _setState(UserProfileState.updated);
      
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_state == UserProfileState.updated) {
          _setState(UserProfileState.loaded);
        }
      });
      
      return true;
    } catch (e) {
      _setError(_extractUserFriendlyMessage(e.toString()));
      return false;
    }
  }

  void clearError() {
    _clearError();
    if (_state == UserProfileState.error) {
      _setState(_user != null ? UserProfileState.loaded : UserProfileState.initial);
    }
  }

  void reset() {
    _user = null;
    _errorMessage = null;
    _setState(UserProfileState.initial);
  }

  String _extractUserFriendlyMessage(String error) {
    return error
      .replaceAll('UserRepositoryException: ', '')
      .replaceAll('UpdateUserException: ', '')
      .replaceAll('Validation failed: ', '');
  }

  void _setState(UserProfileState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _setState(UserProfileState.error);
  }

  void _clearError() => _errorMessage = null;
}