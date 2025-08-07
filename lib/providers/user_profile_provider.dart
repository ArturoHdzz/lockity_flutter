import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lockity_flutter/models/user.dart';
import 'package:lockity_flutter/models/user_update_request.dart';
import 'package:lockity_flutter/use_cases/get_current_user_use_case.dart';
import 'package:lockity_flutter/use_cases/update_user_use_case.dart';
import 'package:lockity_flutter/services/user_update_cooldown_service.dart';

enum UserProfileState { initial, loading, loaded, updating, updated, error }

class UserProfileProvider extends ChangeNotifier {
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final UpdateUserUseCase _updateUserUseCase;
  final UserUpdateCooldownService _cooldownService;

  UserProfileProvider({
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required UpdateUserUseCase updateUserUseCase,
    UserUpdateCooldownService? cooldownService,
  }) : _getCurrentUserUseCase = getCurrentUserUseCase,
       _updateUserUseCase = updateUserUseCase,
       _cooldownService = cooldownService ?? UserUpdateCooldownService() {
    _initializeCooldown();
  }

  UserProfileState _state = UserProfileState.initial;
  User? _user;
  String? _errorMessage;
  bool _disposed = false;

  UserProfileState get state => _state;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == UserProfileState.loading;
  bool get isUpdating => _state == UserProfileState.updating;
  bool get hasError => _state == UserProfileState.error;
  bool get hasUser => _user != null;
  
  bool get canUpdate => !_cooldownService.isInCooldown && !isUpdating;
  bool get isInCooldown => _cooldownService.isInCooldown;
  int get remainingMinutes => _cooldownService.remainingMinutes;
  String get cooldownFormattedTime => _cooldownService.formattedTime;

  void _initializeCooldown() {
    _cooldownService.addListener(_onCooldownChanged);
    _cooldownService.initialize();
  }

  void _onCooldownChanged() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> loadUserProfile() async {
    if (_state == UserProfileState.loading || _disposed) return;

    _setState(UserProfileState.loading);
    _clearError();

    try {
      _user = await _getCurrentUserUseCase.execute();
      if (!_disposed) {
        _setState(UserProfileState.loaded);
      }
    } catch (e) {
      if (!_disposed) {
        _setError(_extractUserFriendlyMessage(e.toString()));
      }
    }
  }

  Future<bool> updateUserProfile({
    required String name,
    required String lastName,
    required String secondLastName,
  }) async {
    if (!canUpdate || _disposed) return false;

    _setState(UserProfileState.updating);
    _clearError();

    try {
      final request = UserUpdateRequest(
        name: name.trim(),
        lastName: lastName.trim(),
        secondLastName: secondLastName.trim(),
      );

      _user = await _updateUserUseCase.execute(request);
      
      if (!_disposed) {
        _setState(UserProfileState.updated);
        
        await _cooldownService.startCooldown();
        
        Timer.run(() {
          if (!_disposed && _state == UserProfileState.updated) {
            _setState(UserProfileState.loaded);
          }
        });
      }
      
      return true;
    } catch (e) {
      if (!_disposed) {
        _setError(_extractUserFriendlyMessage(e.toString()));
      }
      return false;
    }
  }

  void clearError() {
    if (_disposed) return;
    
    _clearError();
    if (_state == UserProfileState.error) {
      _setState(_user != null ? UserProfileState.loaded : UserProfileState.initial);
    }
  }

  void reset() {
    if (_disposed) return;
    
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
    if (_disposed) return;
    
    _state = newState;
    notifyListeners();
  }

  void _setError(String error) {
    if (_disposed) return;
    
    _errorMessage = error;
    _setState(UserProfileState.error);
  }

  void _clearError() => _errorMessage = null;

  @override
  void dispose() {
    _disposed = true;
    _cooldownService.removeListener(_onCooldownChanged);
    super.dispose();
  }
}