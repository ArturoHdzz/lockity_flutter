import 'package:flutter/foundation.dart';
import 'package:lockity_flutter/models/locker.dart';
import 'package:lockity_flutter/models/compartment.dart';
import 'package:lockity_flutter/models/locker_config_response.dart';
import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/use_cases/get_lockers_use_case.dart';
import 'package:lockity_flutter/use_cases/control_locker_use_case.dart';

enum LockerState { initial, loading, loaded, operating, error }

class LockerProvider extends ChangeNotifier {
  final GetLockersUseCase _getLockersUseCase;
  final ControlLockerUseCase _controlLockerUseCase;

  LockerProvider({
    required GetLockersUseCase getLockersUseCase,
    required ControlLockerUseCase controlLockerUseCase,
  }) : _getLockersUseCase = getLockersUseCase,
       _controlLockerUseCase = controlLockerUseCase;

  LockerState _state = LockerState.initial;
  List<Locker> _lockers = [];
  Locker? _selectedLocker;
  List<Compartment> _compartments = [];
  Compartment? _selectedCompartment;
  String? _errorMessage;

  LockerConfigResponse? _lockerConfig;

  LockerState get state => _state;
  List<Locker> get lockers => List.unmodifiable(_lockers);
  Locker? get selectedLocker => _selectedLocker;
  List<Compartment> get compartments => List.unmodifiable(_compartments);
  Compartment? get selectedCompartment => _selectedCompartment;
  String? get errorMessage => _errorMessage;
  LockerConfigResponse? get lockerConfig => _lockerConfig;

  bool get isLoading => _state == LockerState.loading;
  bool get isOperating => _state == LockerState.operating;
  bool get hasError => _state == LockerState.error;
  bool get isEmpty => _lockers.isEmpty && _state == LockerState.loaded;
  bool get canOperate => _selectedLocker?.canOperate == true && 
                        _selectedCompartment?.canOperate == true &&
                        !isOperating;

  Future<void> loadLockers() async {
    if (_state == LockerState.loading) return;
    _setState(LockerState.loading);
    _clearError();
    _lockers.clear();
    _clearSelection();
    try {
      final request = const LockerListRequest();
      final response = await _getLockersUseCase.execute(request);
      _lockers = response.items;
      _setState(LockerState.loaded);
    } catch (e) {
      _setError(_extractUserFriendlyMessage(e.toString()));
    }
  }

  Future<void> selectLocker(Locker locker) async {
    _selectedLocker = locker;
    _compartments = locker.compartments;
    _selectedCompartment = locker.compartments.isNotEmpty ? locker.compartments.first : null;
    notifyListeners();
    final config = await _getLockersUseCase.repository.getLockerConfig(locker.serialNumber);
    _lockerConfig = config;
  }

  void selectCompartment(Compartment compartment) {
    _selectedCompartment = compartment;
    notifyListeners();
  }

  Future<bool> openSelectedCompartment() async {
    if (!canOperate || _selectedLocker == null || _selectedCompartment == null) {
      return false;
    }
    _setState(LockerState.operating);
    _clearError();
    try {
      final topic = _lockerConfig?.topics['toggle'];
      if (topic == null) throw Exception('No topic for toggle');
      
      await _controlLockerUseCase.openCompartment(
        lockerId: _selectedLocker!.id,
        compartmentId: _selectedCompartment!.id,
        topic: topic, 
      );
      
      final updatedCompartments = _compartments.map((comp) {
        if (comp.id == _selectedCompartment!.id) {
          return Compartment(
            id: comp.id,
            compartmentNumber: comp.compartmentNumber,
            status: 'open',
            userId: comp.userId,
            users: comp.users,
          );
        }
        return comp;
      }).toList();
      _compartments = updatedCompartments;
      _selectedCompartment = updatedCompartments.firstWhere(
        (comp) => comp.id == _selectedCompartment!.id,
      );
      
      _setState(LockerState.loaded);
      return true;
    } catch (e) {
      _setError(_extractUserFriendlyMessage(e.toString()));
      return false;
    }
  }

  Future<bool> activateAlarm() async {
    if (_selectedLocker == null || isOperating) return false;
    _setState(LockerState.operating);
    _clearError();
    try {
      final topic = _lockerConfig?.topics['alarm'];
      if (topic == null) throw Exception('No topic for alarm');
      await _controlLockerUseCase.activateAlarm(
        lockerId: _selectedLocker!.id,
        topic: topic,
      );
      _setState(LockerState.loaded);
      return true;
    } catch (e) {
      _setError(_extractUserFriendlyMessage(e.toString()));
      return false;
    }
  }

  Future<bool> takePicture() async {
    if (_selectedLocker == null || isOperating) return false;
    _setState(LockerState.operating);
    _clearError();
    try {
      final topic = _lockerConfig?.topics['picture'];
      if (topic == null) throw Exception('No topic for picture');
      await _controlLockerUseCase.takePicture(
        lockerId: _selectedLocker!.id,
        topic: topic, 
      );
      _setState(LockerState.loaded);
      return true;
    } catch (e) {
      _setError(_extractUserFriendlyMessage(e.toString()));
      return false;
    }
  }

  void clearError() {
    _clearError();
    if (_state == LockerState.error) {
      _setState(_lockers.isNotEmpty ? LockerState.loaded : LockerState.initial);
    }
  }

  void reset() {
    _lockers.clear();
    _compartments.clear();
    _clearSelection();
    _errorMessage = null;
    _setState(LockerState.initial);
  }

  void _clearSelection() {
    _selectedLocker = null;
    _selectedCompartment = null;
  }

  String _extractUserFriendlyMessage(String error) {
    return error
      .replaceAll('LockerRepositoryException: ', '')
      .replaceAll('ControlLockerException: ', '')
      .replaceAll('Exception: ', '');
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void _setState(LockerState newState) {
    if (_isDisposed) return;
    _state = newState;
    notifyListeners();
  }

  void _setError(String error) {
    if (_isDisposed) return;
    _errorMessage = error;
    _setState(LockerState.error);
  }

  void _clearError() => _errorMessage = null;

}