import 'package:flutter/foundation.dart';
import 'package:lockity_flutter/models/locker.dart';
import 'package:lockity_flutter/models/compartment.dart';
import 'package:lockity_flutter/models/locker_config_response.dart';
import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/use_cases/get_lockers_use_case.dart';
import 'package:lockity_flutter/use_cases/control_locker_use_case.dart';
import 'package:lockity_flutter/models/compartment_status_response.dart';

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
  CompartmentStatusResponse? _compartmentStatus;
  bool _isRefreshingStatus = false;

  // Getters
  LockerState get state => _state;
  List<Locker> get lockers => List.unmodifiable(_lockers);
  Locker? get selectedLocker => _selectedLocker;
  List<Compartment> get compartments => List.unmodifiable(_compartments);
  Compartment? get selectedCompartment => _selectedCompartment;
  String? get errorMessage => _errorMessage;
  LockerConfigResponse? get lockerConfig => _lockerConfig;
  CompartmentStatusResponse? get compartmentStatus => _compartmentStatus;
  bool get isRefreshingStatus => _isRefreshingStatus;

  bool get isLoading => _state == LockerState.loading;
  bool get isOperating => _state == LockerState.operating;
  bool get hasError => _state == LockerState.error;
  bool get isEmpty => _lockers.isEmpty && _state == LockerState.loaded;
  bool get canOperate => _selectedLocker?.canOperate == true && 
                        _selectedCompartment?.canOperate == true &&
                        !isOperating && !_isRefreshingStatus;

  Future<void> loadLockers() async {
    if (_state == LockerState.loading) return;
    
    print('📥 Cargando lockers desde el servidor...');
    _setState(LockerState.loading);
    _clearError();
    _lockers.clear();
    _clearSelection();
    
    try {
      final request = const LockerListRequest();
      final response = await _getLockersUseCase.execute(request);
      _lockers = response.items;
      _setState(LockerState.loaded);
      
      print('✅ Lockers cargados: ${_lockers.length}');
      
      if (_lockers.isNotEmpty) {
        await selectLocker(_lockers.first);
      }
      
    } catch (e) {
      print('❌ Error cargando lockers: $e');
      _setError(_extractUserFriendlyMessage(e.toString()));
    }
  }

  Future<void> selectLocker(Locker locker) async {
    print('🔄 Seleccionando locker: ${locker.displayName}');
    
    _compartmentStatus = null;
    _lockerConfig = null;
    
    _selectedLocker = locker;
    _compartments = locker.compartments;
    
    _selectedCompartment = locker.compartments.isNotEmpty ? locker.compartments.first : null;
    
    notifyListeners();
    
    try {
      print('📡 Cargando configuración del locker...');
      final config = await _getLockersUseCase.repository.getLockerConfig(locker.serialNumber);
      _lockerConfig = config;
      
      print('✅ Configuración del locker cargada');
      
      if (_selectedCompartment != null) {
        await _refreshCompartmentStatus();
      }
      
    } catch (e) {
      print('❌ Error cargando configuración del locker: $e');
      _setError(_extractUserFriendlyMessage(e.toString()));
    }
  }

  Future<void> selectCompartment(Compartment compartment) async {
    print('🔄 Seleccionando compartimento: ${compartment.displayName}');
    
    _selectedCompartment = compartment;
    notifyListeners();
    
    await _refreshCompartmentStatus();
  }

  Future<void> _refreshCompartmentStatus() async {
    if (_selectedLocker == null || _selectedCompartment == null) {
      _compartmentStatus = null;
      notifyListeners();
      return;
    }

    print('🔍 Consultando estado del compartimento ${_selectedCompartment!.displayName}...');
    _isRefreshingStatus = true;
    notifyListeners();

    try {
      final status = await _controlLockerUseCase.getCompartmentStatus(
        serialNumber: _selectedLocker!.serialNumber,
        compartmentNumber: _selectedCompartment!.compartmentNumber,
      );

      _compartmentStatus = status;
      print('✅ Estado del compartimento actualizado: ${status.message}');

    } catch (e) {
      print('❌ Error consultando estado del compartimento: $e');
      _compartmentStatus = null;
    } finally {
      _isRefreshingStatus = false;
      notifyListeners();
    }
  }

  Future<bool> refreshCompartmentStatus() async {
    await _refreshCompartmentStatus();
    return _compartmentStatus != null;
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
        compartmentId: _selectedCompartment!.compartmentNumber,
        topic: topic, 
      );
      
      _setState(LockerState.loaded);
      
      await _refreshCompartmentStatus();
      
      return true;
    } catch (e) {
      _setError(_extractUserFriendlyMessage(e.toString()));
      return false;
    }
  }

  Future<bool> toggleSelectedCompartment() async {
    if (!canOperate || _selectedLocker == null || _selectedCompartment == null) {
      return false;
    }

    await _refreshCompartmentStatus();
    
    if (_compartmentStatus == null) {
      _setError('Could not determine compartment status');
      return false;
    }

    _setState(LockerState.operating);
    _clearError();

    try {
      final topic = _lockerConfig?.topics['toggle'];
      if (topic == null) throw Exception('No topic for toggle');
      
      await _controlLockerUseCase.toggleCompartmentStatus(
        lockerId: _selectedLocker!.id,
        serialNumber: _selectedLocker!.serialNumber,
        compartmentNumber: _selectedCompartment!.compartmentNumber,
        topic: topic, 
      );
      
      _setState(LockerState.loaded);
      
      await _refreshCompartmentStatus();
      
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
    _compartmentStatus = null;
    _lockerConfig = null;
    _isRefreshingStatus = false;
    _setState(LockerState.initial);
  }

  void _clearSelection() {
    _selectedLocker = null;
    _selectedCompartment = null;
    _compartmentStatus = null;
    _lockerConfig = null;
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