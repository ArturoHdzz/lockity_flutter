import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ButtonCooldownService extends ChangeNotifier {
  static const String _cooldownKey = 'button_cooldown_timestamp';
  static const int _cooldownDurationSeconds = 20;
  
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _isInCooldown = false;
  
  Future<void> Function()? _onCooldownFinished;
  
  static final ButtonCooldownService _instance = ButtonCooldownService._internal();
  factory ButtonCooldownService() => _instance;
  ButtonCooldownService._internal();
  
  bool get isInCooldown => _isInCooldown;
  int get remainingSeconds => _remainingSeconds;
  double get progressPercentage => _remainingSeconds / _cooldownDurationSeconds;
  
  void setOnCooldownFinishedCallback(Future<void> Function()? callback) {
    _onCooldownFinished = callback;
  }
  
  Future<void> initialize() async {
    await _checkExistingCooldown();
  }
  
  Future<void> _checkExistingCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampString = prefs.getString(_cooldownKey);
      
      if (timestampString != null) {
        final data = json.decode(timestampString) as Map<String, dynamic>;
        final endTime = DateTime.fromMillisecondsSinceEpoch(data['endTime']);
        final compartmentKey = data['compartmentKey'] as String?;
        
        final now = DateTime.now();
        
        if (now.isBefore(endTime)) {
          final remainingMs = endTime.difference(now).inMilliseconds;
          _remainingSeconds = (remainingMs / 1000).ceil();
          _isInCooldown = true;
          
          print('🔒 Cooldown activo encontrado: $_remainingSeconds segundos restantes');
          print('🔑 Para compartimento: $compartmentKey');
          
          _startCountdown();
        } else {
          await _clearCooldown();
        }
      }
    } catch (e) {
      print('❌ Error verificando cooldown existente: $e');
      await _clearCooldown();
    }
  }
  
  Future<void> startCooldown({
    required String serialNumber,
    required int compartmentNumber,
  }) async {
    if (_isInCooldown) {
      print('⚠️ Cooldown ya está activo, ignorando nueva solicitud');
      return;
    }
    
    final compartmentKey = '$serialNumber-$compartmentNumber';
    final endTime = DateTime.now().add(Duration(seconds: _cooldownDurationSeconds));
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'endTime': endTime.millisecondsSinceEpoch,
        'compartmentKey': compartmentKey,
        'startTime': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString(_cooldownKey, json.encode(data));
      
      _remainingSeconds = _cooldownDurationSeconds;
      _isInCooldown = true;
      
      print('🔒 Cooldown iniciado para $compartmentKey - $_cooldownDurationSeconds segundos');
      
      _startCountdown();
      notifyListeners();
      
    } catch (e) {
      print('❌ Error iniciando cooldown: $e');
    }
  }
  
  void _startCountdown() {
    _countdownTimer?.cancel();
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds--;
      
      if (_remainingSeconds <= 0) {
        _finishCooldown();
      } else {
        notifyListeners();
      }
    });
  }
  
  Future<void> _finishCooldown() async {
    _countdownTimer?.cancel();
    _isInCooldown = false;
    _remainingSeconds = 0;
    
    await _clearCooldown();
    
    print('✅ Cooldown completado - Botón habilitado');
    
    notifyListeners();
    
    if (_onCooldownFinished != null) {
      try {
        print('🔄 Actualizando estado del compartimento después del cooldown...');
        await _onCooldownFinished!();
        print('✅ Estado del compartimento actualizado correctamente');
      } catch (e) {
        print('❌ Error actualizando estado después del cooldown: $e');
      }
    }
    
    await Future.delayed(const Duration(milliseconds: 50));
  }
  
  Future<void> _clearCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cooldownKey);
    } catch (e) {
      print('❌ Error limpiando cooldown: $e');
    }
  }
  
  Future<void> cancelCooldown() async {
    _countdownTimer?.cancel();
    _isInCooldown = false;
    _remainingSeconds = 0;
    
    await _clearCooldown();
    
    print('🛑 Cooldown cancelado manualmente');
    notifyListeners();
  }
  
  String get formattedTimeRemaining {
    if (!_isInCooldown) return '';
    
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    
    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }
  
  @override
  void dispose() {
    _countdownTimer?.cancel();
    _onCooldownFinished = null;
    super.dispose();
  }
}